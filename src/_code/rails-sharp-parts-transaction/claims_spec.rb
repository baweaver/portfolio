# frozen_string_literal: true

require_relative "transaction"
require_relative "../../../spec/support/claim_helper"

RSpec.describe "Article claims: The Block Is Not the Transaction" do
  include ClaimHelper

  before(:each) do
    Order.delete_all
    LedgerEntry.delete_all
    EMAILS.clear
    COMMITTED.clear
  end

  describe "Failure Two: after_save fires inside rolled-back transaction" do
    it "after_save fires during a transaction that rolls back" do
      result = demonstrate_after_save_vs_after_commit

      claim("orders in database after rollback") { result[:orders_in_database] }.equals(0)
      claim("receipt emails sent inside rolled-back txn") { result[:receipt_emails_sent] }.equals(1)
      claim("after_commit callbacks after rollback") { result[:after_commit_callbacks] }.equals(0)
    end
  end

  describe "Failure Four: fused nesting swallows Rollback" do
    it "both records persist when inner Rollback is swallowed" do
      count = demonstrate_fused_nesting
      claim("fused nesting order count") { count }.equals(2)
    end
  end

  describe "Failure Four: requires_new respects inner rollback" do
    it "only outer record persists" do
      count = demonstrate_requires_new_nesting
      claim("requires_new nesting order count") { count }.equals(1)
    end
  end

  describe "Failure Four: without requires_new, Rollback is swallowed identically" do
    it "both records persist (same as fused)" do
      count = demonstrate_no_requires_new_nesting
      claim("no requires_new nesting order count") { count }.equals(2)
    end
  end

  describe "Failure Four: top-level Rollback returns nil silently" do
    it "returns nil and commits nothing" do
      result = demonstrate_top_level_rollback
      claim("top-level Rollback return value") { result[:return_value] }.equals(nil)
      claim("top-level Rollback order count") { result[:orders] }.equals(0)
    end
  end

  describe "Failure Five: bare update already emits BEGIN/COMMIT" do
    it "single update! wraps itself in a transaction" do
      result = demonstrate_bare_update_sql
      claim("bare update emits BEGIN") { result[:sql].any? { |s| s.match?(/BEGIN/) } }.equals(true)
      claim("bare update emits COMMIT") { result[:sql].any? { |s| s.match?(/COMMIT/) } }.equals(true)
      claim("bare update emits UPDATE") { result[:sql].any? { |s| s.match?(/UPDATE/) } }.equals(true)
    end
  end

  describe "Failure Five: explicit transaction wrapper changes nothing for single write" do
    it "produces identical BEGIN/UPDATE/COMMIT shape" do
      result = demonstrate_wrapped_update_sql
      claim("wrapped update emits BEGIN") { result[:sql].any? { |s| s.match?(/BEGIN/) } }.equals(true)
      claim("wrapped update emits COMMIT") { result[:sql].any? { |s| s.match?(/COMMIT/) } }.equals(true)
      claim("wrapped update emits UPDATE") { result[:sql].any? { |s| s.match?(/UPDATE/) } }.equals(true)
    end
  end

  describe "Failure Four: requires_new emits SAVEPOINT" do
    it "savepoint appears in SQL trace when outer has written" do
      sql = demonstrate_savepoint_trace
      joined = sql.join("\n")
      claim("savepoint emitted") { joined.match?(/SAVEPOINT/) }.equals(true)
      claim("savepoint released") { joined.match?(/RELEASE SAVEPOINT/) }.equals(true)
    end
  end

  describe "Failure Six: cross-database independence" do
    it "inner commit on second database survives outer rollback" do
      result = demonstrate_cross_database_failure
      claim("outer raised") { result[:raised] }.equals("boom after the inner commit")
      claim("orders rolled back") { result[:orders_rolled_back] }.equals(0)
      claim("ledger committed despite outer rollback") { result[:ledger_committed] }.equals(1)
    end
  end

  describe "isolation level on nested transaction" do
    it "raises TransactionIsolationError" do
      result = demonstrate_isolation_error_on_nested
      claim("nested isolation raises correct error") { result[:error_class] }.equals("ActiveRecord::TransactionIsolationError")
    end
  end

  describe "Failure Five: return inside transaction commits on Rails 8" do
    it "return commits the partial transaction (order updated, no ledger entry)" do
      result = demonstrate_return_commits
      claim("return inside transaction commits the update") { result[:order_status] }.equals("paid")
      claim("return skips code after it (no ledger entry)") { result[:ledger_entries] }.equals(0)
    end
  end

  describe "Return fix: conditional logic keeps both writes" do
    it "conditional form commits order and ledger entry together" do
      result = demonstrate_return_fix_conditional
      claim("conditional fix: order status") { result[:order_status] }.equals("paid")
      claim("conditional fix: ledger entry created") { result[:ledger_entries] }.equals(1)
    end
  end

  describe "Return fix: extracted decision skips transaction entirely for zero-cent" do
    it "zero-cent order is never updated" do
      result = demonstrate_return_fix_extract_zero
      claim("extract fix: order stays pending") { result[:order_status] }.equals("pending")
      claim("extract fix: no ledger entry") { result[:ledger_entries] }.equals(0)
    end
  end

  describe "Nested fix: rescue around requires_new allows outer to continue" do
    it "outer record persists despite inner failure" do
      count = demonstrate_nested_fix
      claim("nested fix: outer record persists") { count }.equals(1)
    end
  end

  describe "Broad transaction vs narrow transaction" do
    it "both produce records but narrow holds the connection for less time" do
      result = demonstrate_broad_vs_narrow_transaction
      claim("broad transaction: records created") { result[:broad_orders] }.equals(2)
    end
  end

  describe "Transaction is per connection, not per model" do
    it "LedgerEntry participates in Order.transaction on shared connection" do
      Order.transaction do
        Order.create!(total_cents: 100)
        LedgerEntry.create!(order_id: 1, amount_cents: 100)
        raise ActiveRecord::Rollback
      end

      claim("Order rolled back") { Order.count }.equals(0)
      claim("LedgerEntry also rolled back (same connection)") { LedgerEntry.count }.equals(0)
    end
  end

  describe "InnoDB default isolation level" do
    it "session default is REPEATABLE-READ" do
      level = ActiveRecord::Base.connection.select_value("SELECT @@transaction_isolation")
      claim("MySQL default isolation level") { level }.equals("REPEATABLE-READ")
    end
  end

  describe "Outbox pattern: message commits with business write" do
    it "both rows commit together" do
      result = demonstrate_outbox_pattern
      claim("outbox: order created") { result[:orders] }.equals(1)
      claim("outbox: message created atomically") { result[:outbox_messages] }.equals(1)
    end

    it "both rows roll back together" do
      result = demonstrate_outbox_pattern_rollback
      claim("outbox rollback: no order") { result[:orders] }.equals(0)
      claim("outbox rollback: no message") { result[:outbox_messages] }.equals(0)
    end
  end

  describe "Saga pattern: compensation reverses earlier step" do
    it "compensates by reversing the order on downstream failure" do
      result = demonstrate_saga_compensation
      claim("saga: order was reversed") { result[:order_status] }.equals("payment_reversed")
      claim("saga: order still exists (not deleted)") { result[:order_count] }.equals(1)
    end
  end

  describe "Opening example: side effects fire inside transaction" do
    it "all side effects fire even though they're in the block" do
      result = demonstrate_opening_example_behavior
      claim("opening: order created") { result[:orders] }.equals(1)
      claim("opening: all side effects fired (3 explicit + 1 model callback)") { result[:side_effects_fired] }.equals(4)
    end
  end

  describe "after_commit fix: callback only fires on successful commit" do
    it "does not fire on rollback" do
      result = demonstrate_after_commit_fix
      claim("after_commit_fix: no order on rollback") { result[:orders] }.equals(0)
      claim("after_commit_fix: callback did not fire") { result[:after_commit_fired] }.equals(0)
    end

    it "fires on successful commit" do
      result = demonstrate_after_commit_fix_success
      claim("after_commit_fix: order exists") { result[:orders] }.equals(1)
      claim("after_commit_fix: callback fired") { result[:after_commit_fired] }.equals(1)
    end
  end

  describe "Connection held: transaction duration includes non-DB work" do
    it "holds connection for full block duration including sleep" do
      result = demonstrate_connection_held
      claim("connection_held: elapsed >= 50ms") { result[:elapsed_at_least_50ms] }.equals(true)
      claim("connection_held: writes committed") { result[:orders] }.equals(1)
    end
  end

  describe "Narrow transaction fix: slow work outside, writes fast" do
    it "transaction itself is fast, slow work is outside" do
      result = demonstrate_narrow_transaction_fix
      claim("narrow_fix: txn under 50ms") { result[:txn_under_50ms] }.equals(true)
      claim("narrow_fix: order created") { result[:orders] }.equals(1)
      claim("narrow_fix: ledger created") { result[:ledger] }.equals(1)
    end
  end

  describe "Retry inside: lock held across all attempts" do
    it "holds locks for the cumulative retry duration" do
      result = demonstrate_retry_inside
      claim("retry_inside: all 3 attempts made") { result[:attempts] }.equals(3)
      claim("retry_inside: elapsed >= 40ms (cumulative)") { result[:elapsed_at_least_40ms] }.equals(true)
    end
  end

  describe "Retry outside fix: each attempt gets own transaction" do
    it "retries outside the transaction, order ends up paid" do
      result = demonstrate_retry_outside_fix
      claim("retry_outside: 3 attempts") { result[:attempts] }.equals(3)
      claim("retry_outside: order is paid") { result[:order_status] }.equals("paid")
    end
  end

  describe "Broad transaction fix: batched writes" do
    it "settles all orders in batches" do
      result = demonstrate_broad_transaction_fix
      claim("broad_fix: all 5 settled") { result[:settled] }.equals(5)
    end
  end

  describe "Model callback form of after_commit" do
    it "fires on successful commit" do
      result = demonstrate_model_callback_fires_on_commit
      claim("model callback: fired on commit") { result[:fired] }.equals(1)
    end

    it "does not fire on rollback" do
      result = demonstrate_model_callback_skipped_on_rollback
      claim("model callback: skipped on rollback") { result[:fired] }.equals(0)
    end
  end

  describe "Wire trace: SAVEPOINT emitted when parent is dirty" do
    it "emits SAVEPOINT when outer transaction has already written" do
      result = demonstrate_savepoint_dirty_parent
      claim("dirty parent: SAVEPOINT present") { result[:has_savepoint] }.equals(true)
    end
  end

  describe "Wire trace: ROLLBACK AND CHAIN when parent is clean" do
    it "emits ROLLBACK AND CHAIN with no SAVEPOINT when outer has not written" do
      result = demonstrate_rollback_and_chain_clean_parent
      claim("clean parent: ROLLBACK AND CHAIN present") { result[:has_rollback_and_chain] }.equals(true)
      claim("clean parent: no SAVEPOINT") { result[:has_no_savepoint] }.equals(true)
    end
  end

  describe "DDL/TRUNCATE discards savepoints" do
    it "TRUNCATE inside requires_new causes an error on savepoint release" do
      error = demonstrate_ddl_discards_savepoint
      claim("DDL error occurred") { error.is_a?(Hash) }.equals(true)
      claim("DDL error message mentions savepoint") { error[:message].match?(/savepoint|SAVEPOINT/i) }.equals(true)
    end
  end
end
