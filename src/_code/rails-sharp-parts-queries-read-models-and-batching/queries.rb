# frozen_string_literal: true

require_relative "setup"

# --- The Leak ---

# segment: open_seats
def open_seats = Seat.where(reserved: false)
# end: open_seats

# segment: the_leak
def the_leak
  reserved_before = Seat.where(reserved: true).count
  open_seats.update_all(reserved: true)
  reserved_after = Seat.where(reserved: true).count
  {reserved_before:, reserved_after:}
end
# => {reserved_before: 0, reserved_after: 12}
# end: the_leak

# segment: lazy_fanout
def lazy_fanout
  seats = Seat.order(:id).to_a # one query, before we start counting
  count_statements_for { seats.map { |seat| seat.event.name } }
end
# => 12   (twelve seats, twelve SELECTs)
# end: lazy_fanout

# --- What a Value Is ---

# segment: struct_type_check
def struct_type_check
  Events::Data::EventDetail.new(id: "not-an-int", name: "x", capacity: 1)
end
# => TypeError: Parameter 'id': Can't set Events::Data::EventDetail.id to
#               "not-an-int" (instance of String) - need a Integer
# end: struct_type_check

# segment: struct_immutability
def struct_immutability
  detail = Events::Data::EventDetail.new(id: 1, name: "RubyConf", capacity: 1200)
  detail.id = 99
end
# => NoMethodError: undefined method 'id=' for an instance of Events::Data::EventDetail
# end: struct_immutability

# --- Query Classes ---

# segment: seat_details_query
module Seating
  class SeatDetails < ApplicationQuery
    sig { params(seat_id: Integer).void }
    def initialize(seat_id:) = @seat_id = seat_id

    private

    attr_reader :seat_id
    def payload = {seat_id:}

    sig { returns(Data::SeatDetail) }
    def execute
      attrs = Seat.where(id: seat_id).pick_hash(:id, :event_id, :order_id, :reserved, :reserved_by)
      raise ActiveRecord::RecordNotFound, "Seat #{seat_id}" if attrs.nil?
      Data::SeatDetail.new(**attrs)
    end
  end
end
# end: seat_details_query

# segment: seat_details_demo
def seat_details_demo(seat_id:)
  detail = Seating::SeatDetails.call(seat_id: seat_id)
  # => <Seating::Data::SeatDetail event_id=1 id=1 order_id=1 reserved=false reserved_by=nil>
  detail.respond_to?(:update!)
  # => false
end
# end: seat_details_demo

# segment: leaky_query
module Broken
  class LeakyQuery < ApplicationQuery
    private

    sig { returns(Events::Data::EventDetail) }
    def execute = Event.first!
  end
end
# end: leaky_query

# segment: leaky_query_demo
def leaky_query_demo
  Broken::LeakyQuery.call
end
# => TypeError: Return value: Expected type Events::Data::EventDetail, got type
#               Event with value #<Event id: 1, name: "Event 1", capacity: 100>
# end: leaky_query_demo

# --- One Type System, Both Doors ---

# segment: reserve_seat_command
module Seating
  class ReserveSeat < ApplicationCommand
    class AlreadyReserved < StandardError; end

    sig { params(seat_id: Integer, by: String).void }
    def initialize(seat_id:, by:)
      @seat_id = seat_id
      @by = by
    end

    private

    attr_reader :seat_id, :by
    def payload = {seat_id:, by:}

    sig { returns(Data::ReservedSeat) }
    def execute
      seat = Seat.find(seat_id)
      seat.with_lock do
        raise AlreadyReserved, "seat #{seat_id} is already reserved" if seat.reserved?
        seat.update!(reserved: true, reserved_by: by)
      end
      Data::ReservedSeat.new(id: seat.id, reserved_by: T.must(seat.reserved_by))
    end
  end
end
# end: reserve_seat_command

# segment: reserve_seat_demo
def reserve_seat_demo(seat_id:)
  reserved = Seating::ReserveSeat.call(seat_id: seat_id, by: "brandon")
  # => <Seating::Data::ReservedSeat id=1 reserved_by="brandon">
  reserved.respond_to?(:update!)
  # => false
end
# end: reserve_seat_demo

# --- The N+1 You Can't See ---

# segment: event_details_single
module Events
  class EventDetails < ApplicationQuery
    sig { params(event_id: Integer).void }
    def initialize(event_id:) = @event_id = event_id

    private

    attr_reader :event_id
    def payload = {event_id:}

    sig { returns(Data::EventDetail) }
    def execute
      attrs = Event.where(id: event_id).pick_hash(:id, :name, :capacity)
      raise ActiveRecord::RecordNotFound, "Event #{event_id}" if attrs.nil?
      Data::EventDetail.new(**attrs)
    end
  end
end
# end: event_details_single

# segment: n_plus_one_demo
def n_plus_one_demo
  seats = Seat.order(:id).to_a # one query, before the count
  count_statements_for { seats.map { |seat| Events::EventDetails.call(event_id: seat.event_id) } }
end
# => 12
# end: n_plus_one_demo

# --- The Batched Query ---

# segment: event_details_by_ids
module Events
  class EventDetailsByIds < ApplicationQuery
    sig { params(event_ids: T::Array[Integer]).void }
    def initialize(event_ids:) = @event_ids = event_ids

    private

    attr_reader :event_ids
    def payload = {count: event_ids.size}

    sig { returns(T::Hash[Integer, Data::EventDetail]) }
    def execute
      Event.where(id: event_ids).pluck_hash(:id, :name, :capacity).to_h do |attrs|
        [attrs[:id], Data::EventDetail.new(**attrs)]
      end
    end
  end
end
# end: event_details_by_ids

# segment: batched_demo
def batched_demo
  seats = Seat.order(:id).to_a
  count_statements_for { Events::EventDetailsByIds.call(event_ids: seats.map(&:event_id)) }
end
# => 1
# end: batched_demo

# --- More batched queries for the composite read ---

# segment: seat_details_by_ids
module Seating
  class SeatDetailsByIds < ApplicationQuery
    sig { params(seat_ids: T::Array[Integer]).void }
    def initialize(seat_ids:) = @seat_ids = seat_ids

    private

    attr_reader :seat_ids
    def payload = {count: seat_ids.size}

    sig { returns(T::Hash[Integer, Data::SeatDetail]) }
    def execute
      Seat.where(id: seat_ids).pluck_hash(:id, :event_id, :order_id, :reserved, :reserved_by).to_h do |attrs|
        [attrs[:id], Data::SeatDetail.new(**attrs)]
      end
    end
  end
end
# end: seat_details_by_ids

# segment: order_details_by_ids
module Orders
  class OrderDetailsByIds < ApplicationQuery
    sig { params(order_ids: T::Array[Integer]).void }
    def initialize(order_ids:) = @order_ids = order_ids

    private

    attr_reader :order_ids
    def payload = {count: order_ids.size}

    sig { returns(T::Hash[Integer, Data::OrderDetail]) }
    def execute
      Order.where(id: order_ids).pluck_hash(:id, :region, :status).to_h do |attrs|
        [attrs[:id], Data::OrderDetail.new(**attrs)]
      end
    end
  end
end
# end: order_details_by_ids

# --- The Composite Read ---

# segment: reservation_view_struct
module Fulfillment
  class ReservationView < T::Struct
    const :seat,  Seating::Data::SeatDetail
    const :event, Events::Data::EventDetail
    const :order, T.nilable(Orders::Data::OrderDetail)
  end
end
# end: reservation_view_struct

# segment: reservation_views_naive
module Fulfillment
  class ReservationViewsNaive < ApplicationQuery
    sig { params(seat_ids: T::Array[Integer]).void }
    def initialize(seat_ids:) = @seat_ids = seat_ids

    private

    attr_reader :seat_ids
    def payload = {count: seat_ids.size}

    sig { returns(T::Array[ReservationView]) }
    def execute
      seat_ids.map do |seat_id|
        seat  = Seating::SeatDetails.call(seat_id: seat_id)
        event = Events::EventDetails.call(event_id: seat.event_id)
        order = seat.order_id && Orders::OrderDetailsByIds.call(order_ids: [seat.order_id])[seat.order_id]
        ReservationView.new(seat: seat, event: event, order: order)
      end
    end
  end
end
# end: reservation_views_naive

# segment: reservation_views_naive_demo
def reservation_views_naive_demo
  all_seat_ids = Seat.order(:id).pluck(:id)
  count_statements_for { Fulfillment::ReservationViewsNaive.call(seat_ids: all_seat_ids) }
end
# => 36    (three packs times twelve rows)
# end: reservation_views_naive_demo

# segment: reservation_views_batched
module Fulfillment
  class ReservationViews < ApplicationQuery
    sig { params(seat_ids: T::Array[Integer]).void }
    def initialize(seat_ids:) = @seat_ids = seat_ids

    private

    attr_reader :seat_ids
    def payload = {count: seat_ids.size}

    sig { returns(T::Array[ReservationView]) }
    def execute
      seats  = Seating::SeatDetailsByIds.call(seat_ids: seat_ids)
      events = Events::EventDetailsByIds.call(event_ids: seats.values.map(&:event_id).uniq)
      orders = Orders::OrderDetailsByIds.call(order_ids: seats.values.filter_map(&:order_id).uniq)

      seats.values.map do |seat|
        ReservationView.new(
          seat:  seat,
          event: events.fetch(seat.event_id),
          order: seat.order_id && orders[seat.order_id]
        )
      end
    end
  end
end
# end: reservation_views_batched

# segment: reservation_views_batched_demo
def reservation_views_batched_demo
  all_seat_ids = Seat.order(:id).pluck(:id)
  count_statements_for { Fulfillment::ReservationViews.call(seat_ids: all_seat_ids) }
end
# => 3    (one query per pack, regardless of row count)
# end: reservation_views_batched_demo

# segment: reservation_view_output
def reservation_view_output(seat_id:)
  Fulfillment::ReservationViews.call(seat_ids: [seat_id]).first
end
# => <Fulfillment::ReservationView
#      event=<Events::Data::EventDetail capacity=100 id=1 name="Event 1">
#      order=<Orders::Data::OrderDetail id=1 region="us-west-1" status="open">
#      seat=<Seating::Data::SeatDetail event_id=1 id=1 order_id=1 reserved=false reserved_by=nil>>
# end: reservation_view_output

# --- Batch Loader ---

# segment: batch_loader
def event_detail_for(event_id)
  BatchLoader.for(event_id).batch do |event_ids, loader|
    Events::EventDetailsByIds.call(event_ids: event_ids).each { |id, detail| loader.call(id, detail) }
  end
end
# end: batch_loader

# segment: batch_loader_demo
def batch_loader_demo
  seats = Seat.order(:id).to_a
  placeholders = seats.map { |seat| event_detail_for(seat.event_id) }
  # building the placeholders runs nothing:
  placeholder_count = count_statements_for { seats.map { |seat| event_detail_for(seat.event_id) } }
  # => 0
  # the first access drains the batch:
  resolve_count = count_statements_for { placeholders.map(&:name) }
  # => 1
  {placeholder_count:, resolve_count:}
end
# end: batch_loader_demo

# --- Making It Enforced ---

require "rubocop"

# segment: query_must_not_mutate_cop
module ArticleCops
  class QueryMustNotMutate < RuboCop::Cop::Base
    MUTATIONS = %i[
      save save! update update! update_column update_columns update_all
      destroy destroy! delete delete_all insert_all upsert_all create create!
    ].freeze

    def on_class(class_node)
      return unless class_node.parent_class&.source == "ApplicationQuery"

      class_node.each_descendant(:send) do |node|
        next unless MUTATIONS.include?(node.method_name)

        add_offense(node, message: "Queries read. Put writes in a command in app/public.")
      end
    end
  end
end
# end: query_must_not_mutate_cop
