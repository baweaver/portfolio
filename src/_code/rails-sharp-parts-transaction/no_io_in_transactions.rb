# frozen_string_literal: true

module RuboCop
  module Cop
    module Domain
      # Flags known side-effecting method calls inside transaction or with_lock blocks.
      # These calls cannot be rolled back by the database and create inconsistency windows.
      #
      # @example
      #   # bad
      #   Order.transaction do
      #     order.update!(status: "paid")
      #     FulfillmentJob.perform_async(order.id)
      #   end
      #
      #   # good
      #   Order.transaction do
      #     order.update!(status: "paid")
      #   end
      #   FulfillmentJob.perform_async(order.id)
      #
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
