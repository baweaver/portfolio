# frozen_string_literal: true

require "coverage"
Coverage.start(lines: true, eval: true)
require_relative "queries"

RSpec.configure do |config|
  config.after(:suite) do
    results = Coverage.result
    root = File.expand_path(".", __dir__)
    tracked = results.select { |p, _| p.start_with?(root) && !p.end_with?("_spec.rb") }

    total = 0
    hit = 0
    uncovered_report = []

    tracked.each do |path, data|
      lines = data[:lines]
      file_uncovered = []
      lines.each_with_index do |hits, i|
        next if hits.nil?
        total += 1
        if hits > 0
          hit += 1
        else
          file_uncovered << (i + 1)
        end
      end
      uncovered_report << [path.sub("#{root}/", ""), file_uncovered] unless file_uncovered.empty?
    end

    pct = total > 0 ? (100.0 * hit / total).round(2) : 0
    puts("\n\nCoverage: #{hit}/#{total} lines (#{pct}%)")
    uncovered_report.each { |f, lines| puts("  #{f}: uncovered lines #{lines.join(", ")}") }
    abort("\n\nFAILED: Coverage is #{pct}%, must be 100%.") unless pct == 100.0
  end
end

RSpec.describe "Rails: The Sharp Parts — Queries, Read Models, and Batching" do
  let(:seat) { Seat.first }
  let(:event) { Event.first }
  let(:order) { Order.first }

  before(:each) { seed! }

  describe "The Leak" do
    it "open_seats returns a relation of unreserved seats" do
      expect(open_seats).to be_a(ActiveRecord::Relation)
      expect(open_seats.count).to eq(12)
    end

    it "the_leak writes through a relation" do
      result = the_leak
      expect(result[:reserved_before]).to eq(0)
      expect(result[:reserved_after]).to eq(12)
    end

    it "lazy_fanout fires N queries for N seats" do
      expect(lazy_fanout).to eq(12)
    end
  end

  describe "What a Value Is" do
    it "struct_type_check raises TypeError on bad type" do
      expect { struct_type_check }.to raise_error(TypeError, /Can't set.*id/)
    end

    it "struct_immutability raises NoMethodError on assignment" do
      expect { struct_immutability }.to raise_error(NoMethodError, /id=/)
    end
  end

  describe "Seating::SeatDetails" do
    it "returns a SeatDetail struct" do
      detail = Seating::SeatDetails.call(seat_id: seat.id)
      expect(detail).to be_a(Seating::Data::SeatDetail)
      expect(detail.id).to eq(seat.id)
      expect(detail.event_id).to eq(seat.event_id)
      expect(detail.respond_to?(:update!)).to be(false)
    end

    it "raises RecordNotFound for missing seat" do
      expect { Seating::SeatDetails.call(seat_id: -1) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "seat_details_demo" do
    it "returns false for respond_to?(:update!)" do
      expect(seat_details_demo(seat_id: seat.id)).to be(false)
    end
  end

  describe "Broken::LeakyQuery" do
    it "raises TypeError when returning an AR object instead of struct" do
      expect { leaky_query_demo }.to raise_error(TypeError, /Expected type Events::Data::EventDetail/)
    end
  end

  describe "Seating::ReserveSeat" do
    it "returns a ReservedSeat struct" do
      reserved = Seating::ReserveSeat.call(seat_id: seat.id, by: "brandon")
      expect(reserved).to be_a(Seating::Data::ReservedSeat)
      expect(reserved.id).to eq(seat.id)
      expect(reserved.reserved_by).to eq("brandon")
      expect(reserved.respond_to?(:update!)).to be(false)
    end

    it "raises AlreadyReserved if seat is taken" do
      Seating::ReserveSeat.call(seat_id: seat.id, by: "brandon")
      expect { Seating::ReserveSeat.call(seat_id: seat.id, by: "other") }
        .to raise_error(Seating::ReserveSeat::AlreadyReserved)
    end
  end

  describe "reserve_seat_demo" do
    it "returns false for respond_to?(:update!)" do
      expect(reserve_seat_demo(seat_id: seat.id)).to be(false)
    end
  end

  describe "Events::EventDetails" do
    it "returns an EventDetail struct" do
      detail = Events::EventDetails.call(event_id: event.id)
      expect(detail).to be_a(Events::Data::EventDetail)
      expect(detail.name).to eq("Event 1")
    end

    it "raises RecordNotFound for missing event" do
      expect { Events::EventDetails.call(event_id: -1) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "N+1" do
    it "n_plus_one_demo fires one query per seat" do
      expect(n_plus_one_demo).to eq(12)
    end
  end

  describe "Events::EventDetailsByIds" do
    it "returns a hash of EventDetail structs" do
      ids = Event.pluck(:id)
      result = Events::EventDetailsByIds.call(event_ids: ids)
      expect(result.size).to eq(4)
      expect(result.values.first).to be_a(Events::Data::EventDetail)
    end
  end

  describe "batched_demo" do
    it "fires one query for all events" do
      expect(batched_demo).to eq(1)
    end
  end

  describe "Seating::SeatDetailsByIds" do
    it "returns a hash of SeatDetail structs" do
      ids = Seat.limit(3).pluck(:id)
      result = Seating::SeatDetailsByIds.call(seat_ids: ids)
      expect(result.size).to eq(3)
      expect(result.values.first).to be_a(Seating::Data::SeatDetail)
    end
  end

  describe "Orders::OrderDetailsByIds" do
    it "returns a hash of OrderDetail structs" do
      ids = Order.pluck(:id)
      result = Orders::OrderDetailsByIds.call(order_ids: ids)
      expect(result.size).to eq(3)
      expect(result.values.first).to be_a(Orders::Data::OrderDetail)
    end
  end

  describe "Fulfillment::ReservationViewsNaive" do
    it "fires 3 queries per seat" do
      count = reservation_views_naive_demo
      expect(count).to eq(36)
    end
  end

  describe "Fulfillment::ReservationViews" do
    it "fires only 3 queries total" do
      count = reservation_views_batched_demo
      expect(count).to eq(3)
    end

    it "returns ReservationView structs" do
      views = Fulfillment::ReservationViews.call(seat_ids: [seat.id])
      view = views.first
      expect(view).to be_a(Fulfillment::ReservationView)
      expect(view.seat).to be_a(Seating::Data::SeatDetail)
      expect(view.event).to be_a(Events::Data::EventDetail)
      expect(view.order).to be_a(Orders::Data::OrderDetail)
    end
  end

  describe "reservation_view_output" do
    it "returns a ReservationView" do
      expect(reservation_view_output(seat_id: seat.id)).to be_a(Fulfillment::ReservationView)
    end
  end

  describe "Batch Loader" do
    before { BatchLoader::Executor.ensure_current }

    it "event_detail_for returns a lazy proxy that resolves" do
      proxy = event_detail_for(event.id)
      expect(proxy.name).to eq("Event 1")
    end

    it "batch_loader_demo shows 0 queries for placeholder creation, 1 for resolution" do
      result = batch_loader_demo
      expect(result[:placeholder_count]).to eq(0)
      expect(result[:resolve_count]).to eq(1)
    end
  end

  describe "ApplicationRecord.pluck_hash" do
    it "raises when includes are present" do
      expect { Seat.includes(:event).pluck_hash(:id) }
        .to raise_error(ArgumentError, /reads columns, not associations/)
    end

    it "raises when eager_load is present" do
      expect { Seat.eager_load(:event).pluck_hash(:id) }
        .to raise_error(ArgumentError, /reads columns, not associations/)
    end

    it "raises when preload is present" do
      expect { Seat.preload(:event).pluck_hash(:id) }
        .to raise_error(ArgumentError, /reads columns, not associations/)
    end
  end

  describe "ApplicationQuery base" do
    it "raises NotImplementedError if execute is not defined" do
      klass = Class.new(ApplicationQuery)
      klass.define_method(:initialize) { }
      klass.public_class_method(:new)
      expect { klass.new.call }.to raise_error(NotImplementedError)
    end
  end

  describe "ApplicationCommand base" do
    it "raises NotImplementedError if execute is not defined" do
      klass = Class.new(ApplicationCommand)
      klass.define_method(:initialize) { }
      klass.public_class_method(:new)
      expect { klass.new.call }.to raise_error(NotImplementedError)
    end
  end

  describe "ArticleCops::QueryMustNotMutate" do
    it "flags mutation methods inside ApplicationQuery subclasses" do
      source = <<~RUBY
        class OrderSummary < ApplicationQuery
          def execute
            order = Order.find(1)
            order.update!(viewed_at: Time.now)
          end
        end
      RUBY
      offenses = run_cop(ArticleCops::QueryMustNotMutate, source)
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include("Queries read")
    end

    it "does not flag read-only queries" do
      source = <<~RUBY
        class OrderSummary < ApplicationQuery
          def execute
            Order.where(id: 1).pluck(:id)
          end
        end
      RUBY
      offenses = run_cop(ArticleCops::QueryMustNotMutate, source)
      expect(offenses).to be_empty
    end

    it "does not flag classes that don't inherit from ApplicationQuery" do
      source = <<~RUBY
        class OrderCommand < ApplicationCommand
          def execute
            Order.find(1).update!(status: "done")
          end
        end
      RUBY
      offenses = run_cop(ArticleCops::QueryMustNotMutate, source)
      expect(offenses).to be_empty
    end
  end

  describe "Fulfillment::ReservationView with nil order" do
    it "handles seats without orders" do
      seat_no_order = Seat.create!(event: event, order: nil, reserved: false)
      views = Fulfillment::ReservationViews.call(seat_ids: [seat_no_order.id])
      expect(views.first.order).to be_nil
    end
  end
end

def run_cop(cop_class, source)
  processed = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f)
  cop = cop_class.new
  commissioner = RuboCop::Cop::Commissioner.new([cop])
  result = commissioner.investigate(processed)
  result.offenses
end
