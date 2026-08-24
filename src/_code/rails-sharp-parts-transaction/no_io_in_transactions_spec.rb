# frozen_string_literal: true

require "rubocop"
require "rubocop/rspec/support"
require_relative "no_io_in_transactions"

RSpec.describe RuboCop::Cop::Domain::NoIoInTransactions, :config do
  let(:config) { RuboCop::Config.new }

  it "flags perform_async inside a transaction block" do
    expect_offense(<<~RUBY)
      Order.transaction do
        order.update!(status: "paid")
        FulfillmentJob.perform_async(order.id)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Domain/NoIoInTransactions: Move `perform_async` outside the transaction; it cannot be rolled back.
      end
    RUBY
  end

  it "flags perform_later inside a with_lock block" do
    expect_offense(<<~RUBY)
      order.with_lock do
        order.update!(status: "paid")
        FulfillmentJob.perform_later(order.id)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Domain/NoIoInTransactions: Move `perform_later` outside the transaction; it cannot be rolled back.
      end
    RUBY
  end

  it "flags deliver_later inside a transaction block" do
    expect_offense(<<~RUBY)
      Order.transaction do
        order.update!(status: "paid")
        ReceiptMailer.receipt(order).deliver_later
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Domain/NoIoInTransactions: Move `deliver_later` outside the transaction; it cannot be rolled back.
      end
    RUBY
  end

  it "does not flag perform_async outside a transaction block" do
    expect_no_offenses(<<~RUBY)
      Order.transaction do
        order.update!(status: "paid")
      end
      FulfillmentJob.perform_async(order.id)
    RUBY
  end

  it "does not flag unrelated methods inside a transaction block" do
    expect_no_offenses(<<~RUBY)
      Order.transaction do
        order.update!(status: "paid")
        LedgerEntry.create!(order: order)
      end
    RUBY
  end
end
