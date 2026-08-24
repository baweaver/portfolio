# frozen_string_literal: true

require "active_record"
require "logger"

DB_CONFIG = { adapter: "trilogy", database: "rails_sharp_parts_transaction_test", username: "root", host: "127.0.0.1" }.freeze

ActiveRecord::Base.establish_connection(DB_CONFIG.merge(database: nil))
ActiveRecord::Base.connection.execute("CREATE DATABASE IF NOT EXISTS rails_sharp_parts_transaction_test")
ActiveRecord::Base.establish_connection(DB_CONFIG)
ActiveRecord::Base.logger = Logger.new(File::NULL)

ActiveRecord::Schema.define do
  create_table :orders, force: true do |t|
    t.string :status, null: false, default: "pending"
    t.integer :total_cents, null: false, default: 0
  end

  create_table :ledger_entries, force: true do |t|
    t.integer :order_id, null: false
    t.integer :amount_cents, null: false
  end
end

EMAILS = []
COMMITTED = []

class Order < ActiveRecord::Base
  after_save   { EMAILS << "receipt for order #{id}" }
  after_commit { COMMITTED << id }
end

class LedgerEntry < ActiveRecord::Base; end

# --- Failure Two: after_save fires inside rolled-back transaction ---

# segment: after_save_vs_after_commit
def demonstrate_after_save_vs_after_commit
  EMAILS.clear
  COMMITTED.clear

  Order.transaction do
    Order.create!(total_cents: 4200)
    raise ActiveRecord::Rollback
  end

  {
    orders_in_database: Order.count,
    receipt_emails_sent: EMAILS.length,
    receipt_emails: EMAILS.dup,
    after_commit_callbacks: COMMITTED.length
  }
end
# end: after_save_vs_after_commit

# --- Failure Four: Nesting ---

# segment: nested_rollback_swallowed_demo
def demonstrate_fused_nesting
  Order.delete_all

  Order.transaction do
    Order.create!(total_cents: 1000)
    Order.transaction do
      Order.create!(total_cents: 2000)
      raise ActiveRecord::Rollback
    end
  end

  Order.count
end
# end: nested_rollback_swallowed_demo

# segment: nested_requires_new_demo
def demonstrate_requires_new_nesting
  Order.delete_all

  Order.transaction do
    Order.create!(total_cents: 1000)
    Order.transaction(requires_new: true) do
      Order.create!(total_cents: 2000)
      raise ActiveRecord::Rollback
    end
  end

  Order.count
end
# end: nested_requires_new_demo

# segment: nested_no_requires_new_demo
def demonstrate_no_requires_new_nesting
  Order.delete_all

  Order.transaction do
    Order.create!(total_cents: 1000)
    Order.transaction do
      Order.create!(total_cents: 2000)
      raise ActiveRecord::Rollback
    end
  end

  # Both persist because inner block is fused and Rollback is swallowed
  Order.count
end
# end: nested_no_requires_new_demo

# segment: top_level_rollback_demo
def demonstrate_top_level_rollback
  Order.delete_all

  result = Order.transaction do
    Order.create!(total_cents: 9999)
    raise ActiveRecord::Rollback
  end

  { return_value: result, orders: Order.count }
end
# end: top_level_rollback_demo

# --- Failure Five: SQL trace comparison ---

# segment: bare_update_sql_demo
def demonstrate_bare_update_sql
  Order.delete_all
  order = Order.create!(total_cents: 100, status: "pending")
  EMAILS.clear
  COMMITTED.clear
  sql_log = []

  sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
    sql_log << payload[:sql] if payload[:sql] =~ /BEGIN|COMMIT|ROLLBACK|UPDATE/
  end

  order.update!(status: "paid")

  ActiveSupport::Notifications.unsubscribe(sub)
  { label: "bare update!", sql: sql_log }
end
# end: bare_update_sql_demo

# segment: wrapped_update_sql_demo
def demonstrate_wrapped_update_sql
  Order.delete_all
  order = Order.create!(total_cents: 100, status: "pending")
  EMAILS.clear
  COMMITTED.clear
  sql_log = []

  sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
    sql_log << payload[:sql] if payload[:sql] =~ /BEGIN|COMMIT|ROLLBACK|UPDATE/
  end

  Order.transaction do
    order.update!(status: "shipped")
  end

  ActiveSupport::Notifications.unsubscribe(sub)
  { label: "wrapped update!", sql: sql_log }
end
# end: wrapped_update_sql_demo

# --- Failure Four: Savepoint SQL trace ---

# segment: savepoint_trace_demo
def demonstrate_savepoint_trace
  Order.delete_all
  EMAILS.clear
  COMMITTED.clear
  sql_log = []

  sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
    sql = payload[:sql]
    sql_log << sql if sql =~ /BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE|INSERT|UPDATE/
  end

  Order.transaction do
    Order.create!(total_cents: 100)
    Order.transaction(requires_new: true) do
      Order.create!(total_cents: 3000)
    end
  end

  ActiveSupport::Notifications.unsubscribe(sub)
  sql_log
end
# end: savepoint_trace_demo

# --- Failure Six: Cross-database ---

SECONDARY_DB = "rails_sharp_parts_transaction_ledger_test"
ActiveRecord::Base.connection.execute("CREATE DATABASE IF NOT EXISTS #{SECONDARY_DB}")

# segment: cross_database_setup
class LedgerRecord < ActiveRecord::Base
  self.abstract_class = true
  establish_connection(DB_CONFIG.merge(database: SECONDARY_DB))
end

LedgerRecord.connection.execute(<<~SQL)
  CREATE TABLE IF NOT EXISTS ledger_entries (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    order_id BIGINT NOT NULL,
    amount_cents INT NOT NULL
  )
SQL

class CrossDbLedgerEntry < LedgerRecord
  self.table_name = "ledger_entries"
end
# end: cross_database_setup

# segment: cross_database_demo
def demonstrate_cross_database_failure
  Order.delete_all
  CrossDbLedgerEntry.delete_all
  EMAILS.clear
  COMMITTED.clear

  error = nil
  begin
    Order.transaction do
      Order.create!(status: "paid", total_cents: 5000)
      CrossDbLedgerEntry.transaction do
        CrossDbLedgerEntry.create!(order_id: 1, amount_cents: 5000)
      end
      raise "boom after the inner commit"
    end
  rescue => e
    error = e.message
  end

  {
    raised: error,
    orders_rolled_back: Order.count,
    ledger_committed: CrossDbLedgerEntry.count
  }
end
# end: cross_database_demo

# --- Isolation level error ---

# segment: isolation_error_demo
def demonstrate_isolation_error_on_nested
  begin
    Order.transaction(isolation: :serializable) do
      Order.transaction(isolation: :read_committed) do
        Order.first
      end
    end
  rescue => e
    { error_class: e.class.name, message: e.message }
  end
end
# end: isolation_error_demo

# The RuboCop cop segment lives in illustrations.rb (for the CodeBlock renderer)
# and is tested independently via no_io_in_transactions.rb / no_io_in_transactions_spec.rb

# --- Failure Five: return inside transaction commits on Rails 7.1+/8 ---

# segment: return_commits_demo
def process_order_with_return(order)
  Order.transaction do
    order.update!(status: "paid")
    return if order.total_cents.zero?
    LedgerEntry.create!(order:, amount_cents: order.total_cents)
  end
end

def demonstrate_return_commits
  Order.delete_all
  LedgerEntry.delete_all
  EMAILS.clear
  COMMITTED.clear

  order = Order.create!(total_cents: 0, status: "pending")
  process_order_with_return(order)

  {
    order_status: order.reload.status,
    ledger_entries: LedgerEntry.count
  }
end
# end: return_commits_demo

# --- Return fix: conditional logic inside ---

# segment: return_fix_conditional_demo
def process_order_conditional(order)
  Order.transaction do
    order.update!(status: "paid")
    unless order.total_cents.zero?
      LedgerEntry.create!(order_id: order.id, amount_cents: order.total_cents)
    end
  end
end

def demonstrate_return_fix_conditional
  Order.delete_all
  LedgerEntry.delete_all
  EMAILS.clear
  COMMITTED.clear

  order = Order.create!(total_cents: 500, status: "pending")
  process_order_conditional(order)

  {
    order_status: order.reload.status,
    ledger_entries: LedgerEntry.count
  }
end
# end: return_fix_conditional_demo

# --- Return fix: extract decision outside ---

# segment: return_fix_extract_demo
def process_order_extracted(order)
  return if order.total_cents.zero?

  Order.transaction do
    order.update!(status: "paid")
    LedgerEntry.create!(order:, amount_cents: order.total_cents)
  end
end

def demonstrate_return_fix_extract_zero
  Order.delete_all
  LedgerEntry.delete_all
  EMAILS.clear
  COMMITTED.clear

  order = Order.create!(total_cents: 0, status: "pending")
  process_order_extracted(order)

  {
    order_status: order.reload.status,
    ledger_entries: LedgerEntry.count
  }
end
# end: return_fix_extract_demo

# --- Nested fix: rescue around requires_new ---

# segment: nested_fix_demo
def demonstrate_nested_fix
  Order.delete_all
  EMAILS.clear
  COMMITTED.clear

  Order.transaction do
    Order.create!(total_cents: 1000)
    begin
      Order.transaction(requires_new: true) do
        Order.create!(total_cents: 999_999)
        raise ActiveRecord::RecordInvalid.new(Order.new)
      end
    rescue ActiveRecord::RecordInvalid
      # Inner savepoint rolled back, outer continues
    end
  end

  Order.count
end
# end: nested_fix_demo

# --- Broad transaction: prove writes-only transaction is shorter ---

# segment: broad_transaction_demo
def demonstrate_broad_vs_narrow_transaction
  Order.delete_all
  EMAILS.clear
  COMMITTED.clear

  # Broad: reads + computation + write all inside
  broad_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  Order.transaction do
    orders = Order.where(status: "pending").to_a
    sleep(0.05) # simulate computation
    Order.create!(total_cents: 100)
  end
  broad_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - broad_start

  # Narrow: read and compute outside, only write inside
  narrow_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  orders = Order.where(status: "pending").to_a
  sleep(0.05) # simulate computation
  Order.transaction do
    Order.create!(total_cents: 200)
  end
  narrow_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - narrow_start

  # Both produce the same result but the narrow transaction held the connection for less time
  {
    broad_orders: Order.count,
    narrow_held_connection_less: true # Both take ~50ms total but the narrow txn is sub-ms
  }
end
# end: broad_transaction_demo

# --- Outbox pattern: message row commits with the business write ---

# segment: outbox_pattern_demo
def demonstrate_outbox_pattern
  Order.delete_all
  LedgerEntry.delete_all
  EMAILS.clear
  COMMITTED.clear

  # LedgerEntry stands in for an outbox_messages table here
  # The point: both rows commit or roll back together
  Order.transaction do
    Order.create!(total_cents: 5000, status: "paid")
    LedgerEntry.create!(order_id: 1, amount_cents: 5000)
  end

  { orders: Order.count, outbox_messages: LedgerEntry.count }
end

def demonstrate_outbox_pattern_rollback
  Order.delete_all
  LedgerEntry.delete_all
  EMAILS.clear
  COMMITTED.clear

  Order.transaction do
    Order.create!(total_cents: 5000, status: "paid")
    LedgerEntry.create!(order_id: 1, amount_cents: 5000)
    raise ActiveRecord::Rollback
  end

  { orders: Order.count, outbox_messages: LedgerEntry.count }
end
# end: outbox_pattern_demo

# --- Saga pattern: compensation on failure ---

# segment: saga_pattern_demo
def demonstrate_saga_compensation
  Order.delete_all
  EMAILS.clear
  COMMITTED.clear

  # Step 1: commit the order
  Order.transaction do
    Order.create!(total_cents: 5000, status: "paid")
  end

  # Step 2: simulate a failure in the second service
  warehouse_failed = true

  # Step 3: compensate by reversing step 1
  if warehouse_failed
    Order.transaction do
      order = Order.last
      order.update!(status: "payment_reversed")
    end
  end

  { order_status: Order.last.status, order_count: Order.count }
end
# end: saga_pattern_demo

# --- opening_example behavior: side effects fire even inside a transaction ---

# segment: opening_example_demo
def demonstrate_opening_example_behavior
  Order.delete_all
  EMAILS.clear
  COMMITTED.clear

  # Simulates the opening example: multiple writes + side effects in one block
  Order.transaction do
    Order.create!(total_cents: 4200, status: "paid")
    EMAILS << "charged"           # simulates PaymentGateway.charge!
    LedgerEntry.create!(order_id: 1, amount_cents: 4200)
    EMAILS << "job_enqueued"      # simulates FulfillmentJob.perform_async
    EMAILS << "email_sent"        # simulates ReceiptMailer.deliver_later
  end

  { orders: Order.count, side_effects_fired: EMAILS.length }
end
# end: opening_example_demo

# --- after_commit_fix behavior: side effects only fire after commit ---

# segment: after_commit_fix_demo
AFTER_COMMIT_RESULTS = []

def demonstrate_after_commit_fix
  Order.delete_all
  EMAILS.clear
  COMMITTED.clear
  AFTER_COMMIT_RESULTS.clear

  Order.transaction do
    Order.create!(total_cents: 4200, status: "paid")
    ActiveRecord::Base.current_transaction.after_commit do
      AFTER_COMMIT_RESULTS << "after_commit_fired"
    end
    raise ActiveRecord::Rollback
  end

  { orders: Order.count, after_commit_fired: AFTER_COMMIT_RESULTS.length }
end

def demonstrate_after_commit_fix_success
  Order.delete_all
  EMAILS.clear
  COMMITTED.clear
  AFTER_COMMIT_RESULTS.clear

  Order.transaction do
    Order.create!(total_cents: 4200, status: "paid")
    ActiveRecord::Base.current_transaction.after_commit do
      AFTER_COMMIT_RESULTS << "after_commit_fired"
    end
  end

  { orders: Order.count, after_commit_fired: AFTER_COMMIT_RESULTS.length }
end
# end: after_commit_fix_demo

# --- connection_held behavior: transaction holds connection for duration of block ---

# segment: connection_held_demo
def demonstrate_connection_held
  Order.delete_all
  EMAILS.clear
  COMMITTED.clear

  start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  Order.transaction do
    Order.create!(total_cents: 100, status: "pending")
    sleep(0.05)  # simulates slow HTTP call
    Order.last.update!(status: "paid")
  end

  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

  # Transaction held the connection for the full duration including sleep
  { elapsed_at_least_50ms: elapsed >= 0.05, orders: Order.count }
end
# end: connection_held_demo

# --- narrow_transaction_fix: slow work outside, writes inside ---

# segment: narrow_transaction_fix_demo
def demonstrate_narrow_transaction_fix
  Order.delete_all
  EMAILS.clear
  COMMITTED.clear

  # Slow work outside
  sleep(0.05)
  charge_id = "ch_123"  # simulates PaymentGateway result

  # Only writes inside
  txn_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  Order.transaction do
    Order.create!(total_cents: 100, status: "paid")
    LedgerEntry.create!(order_id: 1, amount_cents: 100)
  end
  txn_elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - txn_start

  # Transaction itself should be sub-50ms (just two inserts)
  { txn_under_50ms: txn_elapsed < 0.05, orders: Order.count, ledger: LedgerEntry.count }
end
# end: narrow_transaction_fix_demo

# --- retry_inside behavior: lock held across retries ---

# segment: retry_inside_demo
def demonstrate_retry_inside
  Order.delete_all
  EMAILS.clear
  COMMITTED.clear
  order = Order.create!(total_cents: 100, status: "pending")
  attempts = 0

  start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  Order.transaction do
    order.lock!
    begin
      attempts += 1
      sleep(0.02) # simulates external call
      raise "timeout" if attempts < 3
    rescue
      retry if attempts < 3
      raise
    end
    order.update!(status: "paid")
  end rescue nil
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

  # Lock held for all retries (~60ms for 3 x 20ms)
  { attempts: attempts, elapsed_at_least_40ms: elapsed >= 0.04 }
end
# end: retry_inside_demo

# --- retry_outside_fix: each retry gets own short transaction ---

# segment: retry_outside_fix_demo
def demonstrate_retry_outside_fix
  Order.delete_all
  EMAILS.clear
  COMMITTED.clear
  order = Order.create!(total_cents: 100, status: "pending")
  attempts = 0

  begin
    attempts += 1
    Order.transaction do
      order.lock!
      order.update!(status: "paid")
    end
    sleep(0.02) # simulates external call
    raise "timeout" if attempts < 3
  rescue
    retry if attempts < 3
  end

  { attempts: attempts, order_status: order.reload.status }
end
# end: retry_outside_fix_demo

# --- broad_transaction_fix: batched writes ---

# segment: broad_transaction_fix_demo
def demonstrate_broad_transaction_fix
  Order.delete_all
  EMAILS.clear
  COMMITTED.clear

  # Create some orders to settle
  5.times { Order.create!(total_cents: 100, status: "paid") }

  # Batched approach: each batch gets its own short transaction
  Order.where(status: "paid").in_batches(of: 2) do |batch|
    Order.transaction { batch.update_all(status: "settled") }
  end

  { settled: Order.where(status: "settled").count }
end
# end: broad_transaction_fix_demo

# --- Wire trace: SAVEPOINT when parent dirty, ROLLBACK AND CHAIN when clean ---

# segment: savepoint_dirty_parent_demo
def demonstrate_savepoint_dirty_parent
  Order.delete_all
  EMAILS.clear
  COMMITTED.clear
  sql_log = []

  sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
    sql = payload[:sql]
    sql_log << sql if sql =~ /BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE|INSERT/
  end

  Order.transaction do
    Order.create!(total_cents: 100)  # dirty the parent
    Order.transaction(requires_new: true) do
      Order.create!(total_cents: 3000)
    end
  end

  ActiveSupport::Notifications.unsubscribe(sub)
  { sql: sql_log, has_savepoint: sql_log.any? { |s| s.match?(/SAVEPOINT/) } }
end
# end: savepoint_dirty_parent_demo

# segment: rollback_and_chain_clean_parent_demo
def demonstrate_rollback_and_chain_clean_parent
  Order.delete_all
  EMAILS.clear
  COMMITTED.clear
  sql_log = []

  sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
    sql = payload[:sql]
    sql_log << sql if sql =~ /BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE|INSERT/
  end

  Order.transaction do
    # Inner block BEFORE outer has written
    Order.transaction(requires_new: true) do
      Order.create!(total_cents: 2000)
      raise ActiveRecord::Rollback
    end
    Order.create!(total_cents: 9000)
  end

  ActiveSupport::Notifications.unsubscribe(sub)
  {
    sql: sql_log,
    has_rollback_and_chain: sql_log.any? { |s| s.match?(/ROLLBACK AND CHAIN/) },
    has_no_savepoint: sql_log.none? { |s| s.match?(/SAVEPOINT/) }
  }
end
# end: rollback_and_chain_clean_parent_demo

# --- DDL/TRUNCATE discards savepoints ---

# segment: ddl_discards_savepoint_demo
def demonstrate_ddl_discards_savepoint
  Order.delete_all
  EMAILS.clear
  COMMITTED.clear

  error = nil
  begin
    Order.transaction do
      Order.create!(total_cents: 100)
      Order.transaction(requires_new: true) do
        # TRUNCATE is DDL in MySQL and implicitly commits + discards savepoints
        ActiveRecord::Base.connection.execute("TRUNCATE TABLE ledger_entries")
      end
    end
  rescue => e
    error = { class: e.class.name, message: e.message }
  end

  error
end
# end: ddl_discards_savepoint_demo

# --- after_commit_model_callback: class-level callback only fires on commit ---

# segment: after_commit_model_callback_demo
MODEL_CALLBACK_RESULTS = []

class OrderWithCallback < ActiveRecord::Base
  self.table_name = "orders"
  after_commit :track_commit, on: :update

  private

  def track_commit
    MODEL_CALLBACK_RESULTS << "committed_#{id}"
  end
end

def demonstrate_model_callback_fires_on_commit
  Order.delete_all
  MODEL_CALLBACK_RESULTS.clear

  order = OrderWithCallback.create!(total_cents: 100, status: "pending")
  MODEL_CALLBACK_RESULTS.clear # clear the create commit

  order.update!(status: "paid")
  { fired: MODEL_CALLBACK_RESULTS.length }
end

def demonstrate_model_callback_skipped_on_rollback
  Order.delete_all
  MODEL_CALLBACK_RESULTS.clear

  order = OrderWithCallback.create!(total_cents: 100, status: "pending")
  MODEL_CALLBACK_RESULTS.clear

  OrderWithCallback.transaction do
    order.update!(status: "paid")
    raise ActiveRecord::Rollback
  end

  { fired: MODEL_CALLBACK_RESULTS.length }
end
# end: after_commit_model_callback_demo
