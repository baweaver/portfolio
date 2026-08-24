# frozen_string_literal: true

require_relative "transaction_pg"
require_relative "../../../spec/support/claim_helper"

RSpec.describe "Article claims: The Block Is Not the Transaction (PostgreSQL)" do
  include ClaimHelper

  before(:each) do
    PgOrder.delete_all
  end

  describe "PostgreSQL default isolation level" do
    it "defaults to read committed" do
      level = demonstrate_pg_default_isolation
      claim("PostgreSQL default isolation level") { level }.equals("read committed")
    end
  end

  describe "PostgreSQL poisoned transaction" do
    it "a rescued StatementInvalid poisons subsequent statements in the same transaction" do
      result = demonstrate_pg_poisoned_transaction

      claim("first error was rescued") { result[:results].include?(:rescued_statement_invalid) }.equals(true)
      claim("second create failed due to poisoned transaction") { result[:results].include?(:second_create_failed) }.equals(true)
      claim("error message mentions aborted transaction") {
        result[:results].any? { |r| r.is_a?(String) && r.include?("current transaction is aborted") }
      }.equals(true)
      claim("nothing committed") { result[:order_count] }.equals(0)
    end
  end

  describe "PostgreSQL idle in transaction detection" do
    it "a sleeping transaction shows as idle in transaction in pg_stat_activity" do
      idle_count = demonstrate_pg_idle_in_transaction
      claim("idle in transaction visible in pg_stat_activity") { idle_count >= 1 }.equals(true)
    end
  end

  describe "PostgreSQL READ COMMITTED snapshot behavior" do
    it "each statement in a transaction sees its own snapshot (no pinning)" do
      result = demonstrate_pg_read_committed_snapshot
      claim("READ COMMITTED sees concurrent insert mid-transaction") { result[:saw_new_record] }.equals(true)
    end
  end
end
