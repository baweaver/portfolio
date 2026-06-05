# frozen_string_literal: true

require "active_record"
require "logger"

DB_CONFIG = { adapter: "trilogy", database: "rails_sharp_parts_lock_test", username: "root", host: "127.0.0.1" }.freeze

# Self-contained: create the database if it doesn't exist
ActiveRecord::Base.establish_connection(DB_CONFIG.merge(database: nil))
ActiveRecord::Base.connection.execute("CREATE DATABASE IF NOT EXISTS rails_sharp_parts_lock_test")
ActiveRecord::Base.establish_connection(DB_CONFIG)
ActiveRecord::Base.logger = Logger.new(File::NULL)
AppLogger = Logger.new($stdout)

ActiveRecord::Schema.define do
  create_table :seats, force: true do |t|
    t.integer :event_id, null: false
    t.boolean :reserved, null: false, default: false
    t.string :reserved_by
    t.integer :lock_version, null: false, default: 0
  end

  create_table :reservations, force: true do |t|
    t.integer :seat_id, null: false
    t.string :reserved_by, null: false
  end
  add_index :reservations, :seat_id, unique: true

  create_table :events, force: true do |t|
    t.string :name
  end

  create_table :admins, force: true do |t|
    t.boolean :on_call, null: false, default: false
  end
end

class Seat < ActiveRecord::Base
  belongs_to :event, optional: true
end

class Reservation < ActiveRecord::Base
  belongs_to :seat
end

class Event < ActiveRecord::Base
  has_many :seats
end

class Admin < ActiveRecord::Base
  scope :on_call, -> { where(on_call: true) }
end

# --- Forking helpers ---

# segment: fork_race
def fork_race(n, &block)
  barrier_read, barrier_write = IO.pipe

  ActiveRecord::Base.connection_pool.disconnect!

  pids = n.times.map do
    fork do
      # :nocov:
      barrier_write.close
      barrier_read.read
      barrier_read.close

      ActiveRecord::Base.establish_connection(DB_CONFIG)

      begin
        block.call
      rescue => e
        exit 1
      end
      # :nocov:
    end
  end

  barrier_read.close
  barrier_write.close

  ActiveRecord::Base.establish_connection(DB_CONFIG)

  pids.map { |pid| Process.waitpid2(pid) }
end
# end: fork_race

# --- Opening example ---

# segment: opening_example
def reserve_seat_basic(seat_id, user_id)
  Seat.transaction do
    seat = Seat.lock.find(seat_id)

    raise "already reserved" if seat.reserved?

    seat.update!(reserved: true, reserved_by: user_id)
  end
end
# end: opening_example

# --- with_lock implementation (for illustration) ---

# segment: with_lock_implementation
def example_with_lock(record, *args, &block)
  transaction_opts = args.extract_options!
  lock = args.present? ? args.first : true
  record.class.transaction(**transaction_opts) { record.lock!(lock); block.call }
end
# end: with_lock_implementation

# --- Failure One: Lost Updates ---

# segment: lost_update_broken
def reserve_seat_no_lock(seat_id, user_id)
  seat = Seat.find(seat_id)
  raise "already reserved" if seat.reserved?
  sleep(0.05)
  Seat.where(id: seat_id).update_all(reserved: true, reserved_by: user_id)
end
# end: lost_update_broken

# segment: lost_update_fixed_lock
def reserve_seat_with_lock(seat_id, user_id)
  Seat.transaction do
    seat = Seat.lock.find(seat_id)
    raise "already reserved" if seat.reserved?
    seat.update!(reserved: true, reserved_by: user_id)
  end
end
# end: lost_update_fixed_lock

# segment: reservation_migration
def reservation_migration
  ActiveRecord::Schema.define do
    create_table :reservations, force: true do |t|
      t.references :seat, null: false, index: false
      t.string :reserved_by, null: false
    end
    add_index :reservations, :seat_id, unique: true
  end
end
# end: reservation_migration

# segment: lost_update_fixed_constraint
def reserve_seat_with_constraint(seat_id, user_id)
  Reservation.create!(seat_id: seat_id, reserved_by: user_id)
rescue ActiveRecord::RecordNotUnique
  raise "already reserved"
end
# end: lost_update_fixed_constraint

# --- Failure Two: Lock Without Transaction ---

# segment: lock_no_transaction
def reserve_seat_lock_no_txn(seat_id, user_id)
  seat = Seat.lock.find(seat_id)
  sleep(0.05)
  Seat.where(id: seat_id).update_all(reserved: true, reserved_by: user_id)
end
# end: lock_no_transaction

# segment: with_lock_usage
def reserve_seat_with_lock_block(seat_id, user_id)
  seat = Seat.find(seat_id)
  seat.with_lock do
    raise "already reserved" if seat.reserved?
    seat.update!(reserved: true, reserved_by: user_id)
  end
end
# end: with_lock_usage

# --- Failure Three: Locking Too Much ---

# segment: lock_too_much
def reserve_any_seat_blocking(event_id, user_id)
  Seat.transaction do
    seats = Seat.where(event_id: event_id, reserved: false).lock.to_a
    seat = seats.first
    raise "sold out" unless seat
    sleep(0.05)
    seat.update!(reserved: true, reserved_by: user_id)
  end
end
# end: lock_too_much

# segment: single_row_lock
def reserve_specific_seat(seat_id, user_id)
  Seat.transaction do
    seat = Seat.lock.find(seat_id)
    seat.update!(reserved: true, reserved_by: user_id)
  end
end
# end: single_row_lock

# segment: lock_skip_locked
def reserve_any_seat_skip_locked(event_id, user_id)
  Seat.transaction do
    seat = Seat
      .where(event_id: event_id, reserved: false)
      .order(:id)
      .lock("FOR UPDATE SKIP LOCKED")
      .first
    raise "sold out" unless seat
    seat.update!(reserved: true, reserved_by: user_id)
  end
end
# end: lock_skip_locked

# --- Failure Four: Long Transactions ---

# segment: long_transaction
def reserve_seat_long_txn(seat_id, user_id)
  Seat.transaction do
    seat = Seat.lock.find(seat_id)
    sleep(0.5) # simulating external call inside the lock
    raise "already reserved" if seat.reserved?
    seat.update!(reserved: true, reserved_by: user_id)
  end
end
# end: long_transaction

# segment: short_transaction
def reserve_seat_short_txn(seat_id, user_id)
  Seat.transaction do
    seat = Seat.lock.find(seat_id)
    raise "already reserved" if seat.reserved?
    seat.update!(reserved: true, reserved_by: user_id)
  end
  sleep(0.5) # external call AFTER the lock is released
end
# end: short_transaction

# segment: nowait_example
def reserve_seat_nowait(seat_id, user_id)
  seat = Seat.find(seat_id)
  seat.with_lock("FOR UPDATE NOWAIT") do
    raise "already reserved" if seat.reserved?
    seat.update!(reserved: true, reserved_by: user_id)
  end
end
# end: nowait_example

# segment: lock_timeout_example
def reserve_seat_with_timeout(seat_id, user_id)
  Seat.with_connection do |c|
    c.execute("SET innodb_lock_wait_timeout = 2")
    c.transaction do
      seat = Seat.lock.find(seat_id)
      raise "already reserved" if seat.reserved?
      seat.update!(reserved: true, reserved_by: user_id)
      # :nocov:
    end
  end
end
# end: lock_timeout_example

# --- Failure Five: Deadlocks ---

# segment: deadlock_broken
def reserve_seats_unordered(seat_ids, user_id)
  Seat.transaction do
    seat_ids.each do |id|
      seat = Seat.lock.find(id)
      sleep(0.1)
      seat.update!(reserved: true, reserved_by: user_id)
      # :nocov:
    end
  end
end
# end: deadlock_broken

# segment: deadlock_fixed
def reserve_seats_ordered(seat_ids, user_id)
  Seat.transaction do
    seats = Seat.where(id: seat_ids).order(:id).lock
    seats.each { |s| s.update!(reserved: true, reserved_by: user_id) }
  end
end
# end: deadlock_fixed

# --- Failure Six: Write Skew ---

# segment: write_skew_broken
def step_down_admin_broken(admin_id)
  Admin.transaction do
    if Admin.on_call.count > 1
      sleep(0.05)
      Admin.find(admin_id).update!(on_call: false)
      # :nocov:
    end
  end
end
# end: write_skew_broken

# segment: write_skew_fixed_serializable
def step_down_admin_serializable(admin_id)
  Admin.transaction(isolation: :serializable) do
    raise "last on-call" if Admin.on_call.count <= 1
    Admin.find(admin_id).update!(on_call: false)
  end
end
# end: write_skew_fixed_serializable

# --- Failure Seven: Phantom Reads ---

# segment: phantom_broken
def reserve_if_under_limit_broken(event_id, user_id, seat_id, limit: 100)
  Seat.transaction do
    count = Seat.where(event_id: event_id, reserved: true).count
    sleep(0.05)
    if count < limit
      Seat.find(seat_id).update!(reserved: true, reserved_by: user_id)
    else
      raise "sold out"
      # :nocov:
    end
  end
end
# end: phantom_broken

# segment: phantom_fixed_aggregate_lock
def reserve_if_under_limit_fixed(event_id, user_id, seat_id, limit: 100)
  Seat.transaction do
    Event.lock.find(event_id)
    count = Seat.where(event_id: event_id, reserved: true).count
    if count < limit
      Seat.find(seat_id).update!(reserved: true, reserved_by: user_id)
    else
      raise "sold out"
      # :nocov:
    end
  end
end
# end: phantom_fixed_aggregate_lock

# --- Optimistic Locking ---

# segment: lock_version_migration
def lock_version_migration
  unless ActiveRecord::Base.connection.column_exists?(:seats, :lock_version)
    ActiveRecord::Schema.define do
      add_column :seats, :lock_version, :integer, null: false, default: 0
      # :nocov:
    end
  end
end
# end: lock_version_migration

# segment: optimistic_locking
def reserve_seat_optimistic(seat_id, user_id, max_retries: 3)
  attempts = 0
  begin
    seat = Seat.find(seat_id)
    raise "already reserved" if seat.reserved?
    seat.update!(reserved: true, reserved_by: user_id)
  rescue ActiveRecord::StaleObjectError
    raise if (attempts += 1) >= max_retries
    retry
  end
end
# end: optimistic_locking

# --- Retry with backoff ---

# segment: retry_with_backoff
def with_retries(max: 3)
  attempts = 0
  begin
    yield
  rescue ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout
    raise if (attempts += 1) >= max
    sleep(rand * 0.05 * attempts)
    retry
  end
end
# end: retry_with_backoff

# --- Instrumentation ---

# segment: slow_sql_subscriber
def setup_slow_sql_logging
  ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
    next unless payload[:duration] && payload[:duration] > 100
    AppLogger.warn("[SQL] #{payload[:duration].round}ms #{payload[:sql]}")
  end
end
# end: slow_sql_subscriber

# --- Callers You Don't Control ---

# segment: careful_lock_example
def reserve_seat_careful(seat_id, user_id)
  Seat.transaction do
    seat = Seat.lock.find(seat_id)
    raise "already reserved" if seat.reserved?
    seat.update!(reserved: true, reserved_by: user_id)
  end
end
# end: careful_lock_example
