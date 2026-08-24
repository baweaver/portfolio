# frozen_string_literal: true

require "active_record"
require "logger"

PG_DB_CONFIG = { adapter: "postgresql", database: "rails_sharp_parts_transaction_pg_test", username: ENV["USER"], host: "127.0.0.1" }.freeze

# Self-contained: create the database if it doesn't exist
ActiveRecord::Base.establish_connection(PG_DB_CONFIG.merge(database: "postgres"))
begin
  ActiveRecord::Base.connection.execute("CREATE DATABASE rails_sharp_parts_transaction_pg_test")
rescue ActiveRecord::StatementInvalid
  # already exists
end
ActiveRecord::Base.establish_connection(PG_DB_CONFIG)
ActiveRecord::Base.logger = Logger.new(File::NULL)

ActiveRecord::Schema.define do
  create_table :orders, force: true do |t|
    t.string :status, null: false, default: "pending"
    t.integer :total_cents, null: false, default: 0
  end
end

class PgOrder < ActiveRecord::Base
  self.table_name = "orders"
end

# --- PostgreSQL default isolation level ---

# segment: pg_default_isolation
def demonstrate_pg_default_isolation
  level = ActiveRecord::Base.connection.select_value("SHOW default_transaction_isolation")
  level
end
# end: pg_default_isolation

# --- PostgreSQL poisoned transaction ---

# segment: pg_poisoned_transaction
def demonstrate_pg_poisoned_transaction
  results = []

  begin
    PgOrder.transaction do
      PgOrder.create!(total_cents: 100)

      # Force a database error (duplicate key on a non-existent constraint — use raw SQL)
      begin
        ActiveRecord::Base.connection.execute("SELECT 1/0") # division by zero
      rescue ActiveRecord::StatementInvalid
        results << :rescued_statement_invalid
      end

      # Try to continue — this should fail on PG with "current transaction is aborted"
      begin
        PgOrder.create!(total_cents: 200)
        results << :second_create_succeeded
      rescue ActiveRecord::StatementInvalid => e
        results << :second_create_failed
        results << e.message
      end
    end
  rescue => e
    results << :outer_raised
    results << e.message
  end

  { results: results, order_count: PgOrder.count }
end
# end: pg_poisoned_transaction

# --- PostgreSQL idle in transaction state ---

# segment: pg_idle_in_transaction
def demonstrate_pg_idle_in_transaction
  # Open a transaction with a sleep to simulate the "phone call" scenario
  # Check pg_stat_activity from another connection to see "idle in transaction"
  thread = Thread.new do
    ActiveRecord::Base.connection_pool.with_connection do |conn|
      conn.execute("BEGIN")
      conn.execute("INSERT INTO orders (status, total_cents) VALUES ('test', 100)")
      sleep(0.5) # simulates HTTP call
      conn.execute("COMMIT")
    end
  end

  sleep(0.1) # let the thread get to the sleep

  # Query pg_stat_activity from main connection
  idle_count = ActiveRecord::Base.connection.select_value(<<~SQL)
    SELECT count(*) FROM pg_stat_activity
    WHERE state = 'idle in transaction'
    AND datname = 'rails_sharp_parts_transaction_pg_test'
  SQL

  thread.join
  PgOrder.delete_all

  idle_count.to_i
end
# end: pg_idle_in_transaction

# --- PostgreSQL READ COMMITTED: each statement sees its own snapshot ---

# segment: pg_read_committed_no_snapshot_pinning
def demonstrate_pg_read_committed_snapshot
  PgOrder.delete_all
  PgOrder.create!(total_cents: 100, status: "original")

  # In READ COMMITTED, a bare transaction wrapping reads does NOT pin a snapshot.
  # Each statement takes its own snapshot.
  # We can prove this by inserting from another thread mid-transaction.

  saw_new_record = false

  PgOrder.transaction do
    count_before = PgOrder.count # snapshot 1

    # Insert from another thread (auto-commits immediately)
    Thread.new {
      ActiveRecord::Base.connection_pool.with_connection do |conn|
        conn.execute("INSERT INTO orders (status, total_cents) VALUES ('sneaked_in', 200)")
      end
    }.join

    count_after = PgOrder.count # snapshot 2 — should see the new row at READ COMMITTED
    saw_new_record = count_after > count_before
  end

  PgOrder.delete_all
  { saw_new_record: saw_new_record }
end
# end: pg_read_committed_no_snapshot_pinning
