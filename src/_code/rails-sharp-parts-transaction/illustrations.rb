# frozen_string_literal: true

# Code segments for "Rails: The Sharp Parts. The Block Is Not the Transaction"
# These are rendered in the article via the CodeBlock component.
# Each segment's behavior is proven by a corresponding _demo segment in transaction.rb
# with claims verified in claims_spec.rb.

# segment: opening_example
def opening_example
  Order.transaction do
    order.update!(status: "paid")
    PaymentGateway.charge!(order)            # HTTP call to the payment provider
    LedgerEntry.create!(order:, amount_cents: order.total_cents)
    FulfillmentJob.perform_async(order.id)
    ReceiptMailer.receipt(order).deliver_later
  end
end
# end: opening_example

# segment: side_effect_escape
def side_effect_escape
  Order.transaction do
    order.update!(status: "paid")
    PaymentGateway.charge!(order)  # charges the card over HTTP
    raise ActiveRecord::Rollback   # oops, something went wrong
  end
  # The order status rolled back. The charge did not.
end
# end: side_effect_escape

# segment: after_commit_fix
def after_commit_fix
  # Charge first, outside the transaction
  charge_result = PaymentGateway.charge!(order)

  # Then wrap only the database writes
  Order.transaction do
    order.update!(status: "paid")
    LedgerEntry.create!(order_id: order.id, amount_cents: order.total_cents, charge_id: charge_result.id)

    # Enqueue downstream work only after COMMIT succeeds
    ApplicationRecord.current_transaction.after_commit do
      FulfillmentJob.perform_async(order.id)
      ReceiptMailer.receipt(order).deliver_later
    end
  end
end
# end: after_commit_fix

# segment: after_commit_model_callback
class Order < ApplicationRecord
  after_commit :enqueue_fulfillment, on: :update, if: -> { saved_change_to_status?(to: "paid") }

  private

  def enqueue_fulfillment
    FulfillmentJob.perform_async(id)
  end
end
# end: after_commit_model_callback

# segment: connection_held
def connection_held
  Order.transaction do
    order.update!(status: "paid")
    PaymentGateway.charge!(order)  # 2 second HTTP timeout
    LedgerEntry.create!(order:, amount_cents: order.total_cents)
  end
end
# end: connection_held

# segment: narrow_transaction_fix
def narrow_transaction_fix
  # Charge first, outside any transaction
  charge_result = PaymentGateway.charge!(order)

  # Then wrap only the database writes
  Order.transaction do
    order.update!(status: "paid")
    LedgerEntry.create!(
      order:,
      amount_cents: order.total_cents,
      charge_id: charge_result.id
    )
  end

  # Enqueue downstream work after commit
  FulfillmentJob.perform_async(order.id)
end
# end: narrow_transaction_fix

# segment: retry_inside
def retry_inside
  Order.transaction do
    attempts = 0
    begin
      order.lock!
      order.update!(status: "paid")
      ExternalService.notify!(order)
    rescue Net::ReadTimeout => e
      attempts += 1
      retry if attempts < 3
      raise
    end
  end
end
# end: retry_inside

# segment: retry_outside_fix
def retry_outside_fix
  attempts = 0
  begin
    Order.transaction do
      order.lock!
      order.update!(status: "paid")
    end
    ExternalService.notify!(order)
  rescue Net::ReadTimeout => e
    attempts += 1
    retry if attempts < 3
    raise
  end
end
# end: retry_outside_fix

# segment: return_inside
def process_order(order)
  Order.transaction do
    order.update!(status: "paid")
    return if order.total_cents.zero?  # <-- early return
    LedgerEntry.create!(order:, amount_cents: order.total_cents)
  end
end
# end: return_inside

# segment: return_fix_conditional
def process_order(order)
  Order.transaction do
    order.update!(status: "paid")
    unless order.total_cents.zero?
      LedgerEntry.create!(order:, amount_cents: order.total_cents)
    end
  end
end
# end: return_fix_conditional

# segment: return_fix_extract
def process_order(order)
  return if order.total_cents.zero?

  Order.transaction do
    order.update!(status: "paid")
    LedgerEntry.create!(order:, amount_cents: order.total_cents)
  end
end
# end: return_fix_extract

# segment: cross_connection
def cross_connection
  Order.transaction do
    order.update!(status: "paid")                    # writes to primary
    WarehouseItem.lock.find_by!(sku:).decrement!(:stock)  # writes to warehouse_db
  end
end
# end: cross_connection



# segment: outbox_pattern
def outbox_pattern
  Order.transaction do
    order.update!(status: "paid")
    OutboxEvent.create!(
      aggregate_type: "Order",
      aggregate_id: order.id,
      event_type: "order.paid",
      payload: { sku: order.sku, quantity: 1 }
    )
  end
  # A background processor reads the outbox and updates the warehouse DB
end
# end: outbox_pattern

# segment: saga_pattern
def saga_pattern
  begin
    Order.transaction { order.update!(status: "paid") }
    WarehouseDb.transaction { WarehouseItem.lock.find_by!(sku:).decrement!(:stock) }
  rescue WarehouseDb::OutOfStock
    # Compensate: undo the order
    Order.transaction { order.update!(status: "payment_reversed") }
    PaymentGateway.refund!(order)
  end
end
# end: saga_pattern

# segment: nested_rollback_swallowed
def nested_rollback_swallowed
  Order.transaction do
    order.update!(status: "processing")

    Order.transaction do
      order.update!(status: "paid")
      raise ActiveRecord::Rollback  # <-- swallowed here
    end

    order.reload
    puts order.status  # => "paid" -- the inner write stuck!
  end
  # COMMIT fires. order.status is "paid" in the DB.
end
# end: nested_rollback_swallowed

# segment: nested_requires_new
def nested_requires_new
  Order.transaction do
    order.update!(status: "processing")

    Order.transaction(requires_new: true) do
      order.update!(status: "paid")
      raise ActiveRecord::Rollback
    end

    # Inner savepoint rolled back, outer continues
    order.reload
    puts order.status  # => "processing"
  end
end
# end: nested_requires_new



# segment: nested_fix
def nested_fix
  Order.transaction do
    order.update!(status: "processing")

    begin
      Order.transaction(requires_new: true) do
        PaymentRecord.create!(order:, amount: order.total)
      end
    rescue ActiveRecord::RecordInvalid => e
      # Handle the failure: the savepoint rolled back,
      # but the outer transaction continues
      order.update!(status: "payment_failed")
    end
  end
end
# end: nested_fix



# segment: rubocop_cop
module RuboCop
  module Cop
    module Domain
      class NoIoInTransactions < Base
        MSG = "Move `%<name>s` outside the transaction; it cannot be rolled back."

        IO_METHODS = %i[
          perform_async perform_later deliver_now deliver_later
          post get put patch delete
        ].freeze

        def_node_matcher :transaction_block?, <<~PATTERN
          (block (send _ {:transaction :with_lock} ...) ...)
        PATTERN

        def on_send(node)
          return unless IO_METHODS.include?(node.method_name)
          return unless node.each_ancestor(:block).any? { |b| transaction_block?(b) }

          add_offense(node, message: format(MSG, name: node.method_name))
        end
      end
    end
  end
end
# end: rubocop_cop
    end
  end
end
# end: rubocop_cop

# segment: broad_transaction
def close_out_day(store_id)
  Order.transaction do
    store  = Store.find(store_id)
    orders = store.orders.where(status: "paid").includes(:line_items)

    report = DailyReport.build_from(orders)          # heavy computation
    orders.find_each { |o| o.update!(status: "settled") }
    store.update!(last_settled_at: Time.current)
  end
end
# end: broad_transaction

# segment: broad_transaction_fix
def close_out_day(store_id)
  store  = Store.find(store_id)
  orders = store.orders.where(status: "paid").includes(:line_items)
  report = DailyReport.build_from(orders)

  orders.in_batches do |batch|
    Order.transaction { batch.update_all(status: "settled") }
  end

  store.update!(last_settled_at: Time.current)
  report
end
# end: broad_transaction_fix

# segment: wrapper_guards_nothing
def wrapper_guards_nothing
  Order.transaction do
    order.update!(status: "paid")
  end
end
# end: wrapper_guards_nothing
