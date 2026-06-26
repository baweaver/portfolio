# frozen_string_literal: true

require "active_record"
require "delegate"

DB_CONFIG = {
  adapter: "trilogy",
  database: "sharp_polymorphic",
  username: "root",
  host: "127.0.0.1"
}.freeze

ActiveRecord::Base.establish_connection(DB_CONFIG.merge(database: nil))
ActiveRecord::Base.connection.execute("CREATE DATABASE IF NOT EXISTS sharp_polymorphic")
ActiveRecord::Base.establish_connection(DB_CONFIG)
ActiveRecord::Base.logger = Logger.new(File::NULL)

ActiveRecord::Schema.define do
  execute "SET FOREIGN_KEY_CHECKS = 0"

  create_table(:events, force: true)
  create_table(:orders, force: true)
  create_table(:seats, force: true)

  create_table(:notes, force: true) do |t|
    t.references :notable, polymorphic: true, null: false
    t.text :body
    t.timestamps
  end

  create_table(:exclusive_notes, force: true) do |t|
    t.references :event, foreign_key: true
    t.references :order, foreign_key: true
    t.references :seat, foreign_key: true
    t.text :body
    t.timestamps
  end

  execute "SET FOREIGN_KEY_CHECKS = 1"

  execute <<~SQL
    ALTER TABLE exclusive_notes
    ADD CONSTRAINT notes_exactly_one_owner
    CHECK (
      (event_id IS NOT NULL) + (order_id IS NOT NULL) + (seat_id IS NOT NULL) = 1
    )
  SQL
end

# --- Models ---

class Event < ActiveRecord::Base
  has_many :notes, as: :notable
end

class Order < ActiveRecord::Base
  has_many :notes, as: :notable
end

class Seat < ActiveRecord::Base
  has_many :notes, as: :notable
end

class Note < ActiveRecord::Base
  belongs_to :notable, polymorphic: true
end

class ExclusiveNote < ActiveRecord::Base
  belongs_to :event, optional: true
  belongs_to :order, optional: true
  belongs_to :seat, optional: true
end

# segment: event_proxy
class EventProxy < SimpleDelegator
  def price_cents
    0 # pretend this calls the new pricing service
  end
end
# end: event_proxy

# --- Seed ---

def seed!
  Note.delete_all
  ExclusiveNote.delete_all
  Event.delete_all
  Order.delete_all
  Seat.delete_all

  event = Event.create!
  order = Order.create!
  seat = Seat.create!

  event.notes.create!(body: "event note")
  order.notes.create!(body: "order note")
  seat.notes.create!(body: "seat note")

  {event:, order:, seat:}
end
