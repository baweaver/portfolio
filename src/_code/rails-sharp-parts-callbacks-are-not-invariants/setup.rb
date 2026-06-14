# frozen_string_literal: true

require "active_record"
require "securerandom"

DB_CONFIG = {
  adapter: "trilogy",
  database: "sharp_callbacks",
  username: "root",
  host: "127.0.0.1"
}.freeze

ActiveRecord::Base.establish_connection(DB_CONFIG.merge(database: nil))
ActiveRecord::Base.connection.execute("CREATE DATABASE IF NOT EXISTS sharp_callbacks")
ActiveRecord::Base.establish_connection(DB_CONFIG)
ActiveRecord::Base.logger = Logger.new(File::NULL)

ActiveRecord::Schema.define do
  create_table(:events, force: true) do |t|
    t.string(:name)
    t.integer(:seats_count, default: 0, null: false)
    t.integer(:capacity, default: 100_000)
    t.timestamps
  end

  create_table(:seats, force: true) do |t|
    t.references(:event)
    t.boolean(:reserved, default: false, null: false)
    t.string(:reserved_by)
    t.string(:external_ref)
    t.boolean(:priority, default: false)
    t.timestamps
  end

  create_table(:orders, force: true) do |t|
    t.string(:region)
    t.string(:email)
    t.timestamps
  end
end

# --- Side-effect tracking (real objects, not stubs) ---

module SideEffects
  LEDGER = []
  EMAILS = []
  WEBHOOKS = []
  SEARCH = []
  LOGS = []

  def self.clear!
    LEDGER.clear
    EMAILS.clear
    WEBHOOKS.clear
    SEARCH.clear
    LOGS.clear
  end
end

# --- Models ---

class Event < ActiveRecord::Base
  has_many :seats
end

class Seat < ActiveRecord::Base
  belongs_to :event, touch: true, counter_cache: true, optional: true
end

class Order < ActiveRecord::Base
end

class PrependedEvent < ActiveRecord::Base
  self.table_name = "events"
  has_many :seats, foreign_key: :event_id, dependent: :destroy
  before_destroy :refuse_if_seated, prepend: true

  def refuse_if_seated
    throw(:abort) if seats.exists?
  end
end

# --- Real service objects that record what they did ---

module Ledger
  module RecordReservation
    def self.call(seat:, by:)
      SideEffects::LEDGER << {seat_id: seat.id, by: by}
    end
  end
end

module SearchIndex
  module IndexSeats
    def self.call(seats:)
      SideEffects::SEARCH << {count: seats.size, ids: seats.map(&:id)}
    end
  end
end

class ReservationMailer
  attr_reader :seat, :type

  def initialize(seat, type)
    @seat = seat
    @type = type
  end

  def self.confirmed(seat)
    new(seat, :reservation)
  end

  def self.final_confirmation(seat)
    new(seat, :confirmation)
  end

  def deliver_later
    SideEffects::EMAILS << {type: type, seat_id: seat.id}
  end
end

class ImportMailer
  attr_reader :count

  def initialize(count)
    @count = count
  end

  def self.completed(count)
    new(count)
  end

  def deliver_later
    SideEffects::EMAILS << {type: :import_completed, count: count}
  end
end

module Webhooks
  module Emit
    def self.call(event:, record:)
      SideEffects::WEBHOOKS << {event: event, record_id: record.id}
    end
  end
end

module Crm
  module SyncOrder
    def self.call(order:)
      SideEffects::WEBHOOKS << {path: :crm_sync, id: order.id}
    end
  end
end

module AppLogger
  def self.info(msg)
    SideEffects::LOGS << msg
  end
end

# --- ApplicationCommand base ---

# segment: application_command
class ApplicationCommand
  def self.call(...)
    new(...).call
  end

  private_class_method :new

  def call
    ActiveSupport::Notifications.instrument(event_name, payload) do
      execute
    end
  end

  private

  def execute
    raise NotImplementedError, "#{self.class.name} must define #execute"
  end

  def payload = {}

  def event_name
    mod = self.class.module_parent_name
    demod = self.class.name&.demodulize&.underscore || "anonymous"

    "#{demod}.#{mod&.underscore || "unknown"}"
  end
end
# end: application_command

# --- Command subclasses ---

# segment: reserve_seat_command
module Seats
  class ReserveSeat < ApplicationCommand
    class AlreadyReserved < StandardError
    end

    def initialize(seat_id:, by:)
      @seat_id = seat_id
      @by = by
    end

    private

    attr_reader :seat_id, :by
    def payload = {seat_id:, by:}

    def execute
      seat = reserve
      announce(seat)
      seat
    end

    def reserve
      seat = Seat.find(seat_id)
      seat.with_lock do
        raise AlreadyReserved, "seat #{seat_id} is already reserved" if seat.reserved?

        seat.update!(reserved: true, reserved_by: by)
        Ledger::RecordReservation.call(seat: seat, by: by)
      end

      seat
    end

    def announce(seat)
      ReservationMailer.confirmed(seat).deliver_later
      Webhooks::Emit.call(event: :seat_reserved, record: seat)
    end
  end
  # end: reserve_seat_command

  # segment: import_seats_command
  class ImportSeats < ApplicationCommand
    def initialize(rows:) = @rows = rows

    private

    def payload = {count: @rows.size}

    def execute
      Seat.insert_all(@rows)

      # insert_all doesn't return records on MySQL (no RETURNING clause);
      # re-query to get the ActiveRecord objects for downstream use.
      seats = Seat.where(external_ref: @rows.pluck(:external_ref))

      SearchIndex::IndexSeats.call(seats: seats)
      ImportMailer.completed(seats.count).deliver_later

      seats
    end
  end
  # end: import_seats_command

  class Forgetful < ApplicationCommand
    def initialize = nil
  end
end

# --- Census helper ---

def census(model)
  %i[validation save create update destroy commit touch].sum do |kind|
    model.send(:"_#{kind}_callbacks").to_a.size
  end
end
