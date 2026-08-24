# frozen_string_literal: true

require_relative "transaction"

RSpec.describe "Rails Sharp Parts: The Block Is Not the Transaction" do
  before(:each) do
    Order.delete_all
    LedgerEntry.delete_all
    EMAILS.clear
    COMMITTED.clear
  end

  describe "after_save_vs_after_commit segment" do
    it "after_save fires even when the transaction rolls back; after_commit does not" do
      result = demonstrate_after_save_vs_after_commit

      expect(result[:orders_in_database]).to eq(0)
      expect(result[:receipt_emails_sent]).to eq(1)
      expect(result[:receipt_emails].first).to match(/receipt for order/)
      expect(result[:after_commit_callbacks]).to eq(0)
    end
  end

  describe "nested_rollback_swallowed_demo segment" do
    it "fused nesting swallows ActiveRecord::Rollback — both records persist" do
      count = demonstrate_fused_nesting
      expect(count).to eq(2)
    end
  end

  describe "nested_requires_new_demo segment" do
    it "requires_new: true creates a savepoint and respects inner rollback" do
      count = demonstrate_requires_new_nesting
      expect(count).to eq(1)
    end
  end

  describe "nested_no_requires_new_demo segment" do
    it "without requires_new, inner Rollback is swallowed and both records persist" do
      count = demonstrate_no_requires_new_nesting
      expect(count).to eq(2)
    end
  end

  describe "top_level_rollback_demo segment" do
    it "top-level Rollback returns nil, raises nothing, commits nothing" do
      result = demonstrate_top_level_rollback
      expect(result[:return_value]).to be_nil
      expect(result[:orders]).to eq(0)
    end
  end

  describe "bare_update_sql_demo segment" do
    it "a bare update! already emits BEGIN/COMMIT without an explicit transaction" do
      result = demonstrate_bare_update_sql
      expect(result[:sql]).to include(match(/BEGIN/))
      expect(result[:sql]).to include(match(/COMMIT/))
      expect(result[:sql]).to include(match(/UPDATE/))
    end
  end

  describe "wrapped_update_sql_demo segment" do
    it "wrapping a single update in transaction produces the same BEGIN/UPDATE/COMMIT" do
      result = demonstrate_wrapped_update_sql
      expect(result[:sql]).to include(match(/BEGIN/))
      expect(result[:sql]).to include(match(/COMMIT/))
      expect(result[:sql]).to include(match(/UPDATE/))
    end
  end

  describe "savepoint_trace_demo segment" do
    it "requires_new emits SAVEPOINT/RELEASE SAVEPOINT when outer has written" do
      sql = demonstrate_savepoint_trace
      joined = sql.join("\n")
      expect(joined).to match(/SAVEPOINT/)
      expect(joined).to match(/RELEASE SAVEPOINT/)
    end
  end

  describe "cross_database_demo segment" do
    it "inner commit on second database survives outer rollback on first database" do
      result = demonstrate_cross_database_failure

      expect(result[:raised]).to eq("boom after the inner commit")
      expect(result[:orders_rolled_back]).to eq(0)
      expect(result[:ledger_committed]).to eq(1)
    end
  end

  describe "isolation_error_demo segment" do
    it "raises TransactionIsolationError when setting isolation inside an open transaction" do
      result = demonstrate_isolation_error_on_nested
      expect(result[:error_class]).to eq("ActiveRecord::TransactionIsolationError")
    end
  end
end
