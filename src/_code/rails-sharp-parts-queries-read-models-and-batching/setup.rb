# frozen_string_literal: true

require "active_record"
require "sorbet-runtime"
require "batch-loader"

DB_CONFIG = {
  adapter: "trilogy",
  database: "sharp_queries",
  username: "root",
  host: "127.0.0.1"
}.freeze

ActiveRecord::Base.establish_connection(DB_CONFIG.merge(database: nil))
ActiveRecord::Base.connection.execute("CREATE DATABASE IF NOT EXISTS sharp_queries")
ActiveRecord::Base.establish_connection(DB_CONFIG)
ActiveRecord::Base.logger = Logger.new(File::NULL)

ActiveRecord::Schema.define do
  create_table(:events, force: true) do |t|
    t.string(:name)
    t.integer(:capacity, default: 100)
    t.timestamps
  end

  create_table(:orders, force: true) do |t|
    t.string(:region)
    t.string(:status, default: "open")
    t.timestamps
  end

  create_table(:seats, force: true) do |t|
    t.references(:event)
    t.references(:order)
    t.boolean(:reserved, default: false, null: false)
    t.string(:reserved_by)
    t.timestamps
  end
end

# --- ApplicationRecord with pluck_hash / pick_hash ---

# segment: application_record
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def self.pluck_hash(*columns)
    reject_associations!
    all.pluck(*columns).map { |row| attribute_hash(columns, row) }
  end

  def self.pick_hash(*columns)
    reject_associations!
    row = all.pick(*columns)
    row && attribute_hash(columns, row)
  end

  def self.reject_associations!
    relation = all
    loaders = relation.includes_values + relation.eager_load_values + relation.preload_values
    raise ArgumentError, "pluck_hash reads columns, not associations; query the association separately" if loaders.any?
  end
  private_class_method :reject_associations!

  def self.attribute_hash(columns, row)
    columns.zip(columns.one? ? [row] : row).to_h
  end
  private_class_method :attribute_hash
end
# end: application_record

# --- Models ---

class Event < ApplicationRecord
  has_many :seats
end

class Seat < ApplicationRecord
  belongs_to :event, optional: true
  belongs_to :order, optional: true
end

class Order < ApplicationRecord
  has_many :seats
end

# --- ApplicationCommand base ---

# segment: application_command
class ApplicationCommand
  extend T::Sig

  def self.call(...)
    new(...).call
  end

  private_class_method :new

  def call
    ActiveSupport::Notifications.instrument(event_name, payload) { execute }
  end

  private

  def execute = raise NotImplementedError, "#{self.class.name} must define #execute"
  def payload = {}

  def event_name
    mod   = self.class.module_parent_name
    demod = self.class.name&.demodulize&.underscore || "anonymous"
    "#{demod}.#{mod&.underscore || "unknown"}"
  end
end
# end: application_command

# --- ApplicationQuery base ---

# segment: application_query
class ApplicationQuery
  extend T::Sig

  def self.call(...) = new(...).call
  private_class_method :new

  def call
    ActiveSupport::Notifications.instrument(event_name, payload) { execute }
  end

  private

  def execute = raise NotImplementedError, "#{self.class.name} must define #execute"
  def payload = {}

  def event_name
    mod   = self.class.module_parent_name
    demod = self.class.name&.demodulize&.underscore || "anonymous"
    "#{demod}.#{mod&.underscore || "unknown"}"
  end
end
# end: application_query

# --- Statement counter ---

# segment: count_statements
def count_statements_for
  total = 0
  sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
    next if event.payload[:name] == "SCHEMA"
    total += 1
  end
  yield
  ActiveSupport::Notifications.unsubscribe(sub)
  total
end
# end: count_statements

# --- Data types ---

# segment: event_detail_struct
module Events
  module Data
    class EventDetail < T::Struct
      const :id, Integer
      const :name, String
      const :capacity, Integer
    end
  end
end
# end: event_detail_struct

# segment: seat_detail_struct
module Seating
  module Data
    class SeatDetail < T::Struct
      const :id, Integer
      const :event_id, Integer
      const :order_id, T.nilable(Integer)
      const :reserved, T::Boolean
      const :reserved_by, T.nilable(String)
    end
  end
end
# end: seat_detail_struct

# segment: reserved_seat_struct
module Seating
  module Data
    class ReservedSeat < T::Struct
      const :id, Integer
      const :reserved_by, String
    end
  end
end
# end: reserved_seat_struct

# segment: order_detail_struct
module Orders
  module Data
    class OrderDetail < T::Struct
      const :id, Integer
      const :region, String
      const :status, String
    end
  end
end
# end: order_detail_struct

# --- Seed data ---

def seed!
  Event.delete_all
  Order.delete_all
  Seat.delete_all

  events = 4.times.map { |i| Event.create!(name: "Event #{i + 1}", capacity: 100) }
  orders = 3.times.map { |i| Order.create!(region: "us-west-#{i + 1}", status: "open") }

  events.each do |event|
    orders.each do |order|
      Seat.create!(event: event, order: order, reserved: false)
    end
  end
end

seed!
