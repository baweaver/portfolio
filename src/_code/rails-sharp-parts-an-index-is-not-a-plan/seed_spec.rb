# frozen_string_literal: true

require_relative "seed"

RSpec.describe "seed.rb" do
  describe "#pick_status" do
    it "returns confirmed for 0..89" do
      (0...90).each { |r| expect(pick_status(r)).to eq("confirmed") }
    end

    it "returns cancelled for 90..97" do
      (90...98).each { |r| expect(pick_status(r)).to eq("cancelled") }
    end

    it "returns pending for 98..99" do
      (98...100).each { |r| expect(pick_status(r)).to eq("pending") }
    end
  end

  describe "#build_row" do
    let(:base_time) { Time.utc(2024, 1, 1).to_i }
    let(:span) { 730 * 24 * 3600 }

    it "returns a parenthesized SQL values string" do
      row = build_row(0, base_time, span)
      expect(row).to start_with("(")
      expect(row).to end_with(")")
    end

    it "contains nine comma-separated fields" do
      row = build_row(42, base_time, span)
      inner = row[1..-2]
      expect(inner.scan(/,(?=(?:[^']*'[^']*')*[^']*$)/).size).to eq(8)
    end

    it "includes the index in the email" do
      row = build_row(777, base_time, span)
      expect(row).to include("user777@")
    end

    it "generates a 12-char uppercase confirmation" do
      row = build_row(0, base_time, span)
      confirmation = row.match(/'([A-Z0-9]{12})'/)[1]
      expect(confirmation.length).to eq(12)
    end

    it "generates a phone starting with 555" do
      row = build_row(0, base_time, span)
      expect(row).to match(/'555\d{7}'/)
    end
  end

  describe "#seed_bookings" do
    before { Booking.delete_all }

    it "inserts the requested number of rows" do
      seed_bookings(row_count: 100, batch_size: 50)
      expect(Booking.count).to eq(100)
    end

    it "produces a skewed status distribution" do
      seed_bookings(row_count: 10_000, batch_size: 5_000)
      confirmed = Booking.where(status: "confirmed").count
      expect(confirmed).to be > 8_000
    end
  end

  describe "Booking model" do
    before { seed_bookings(row_count: 50, batch_size: 50) }

    it "has the expected columns" do
      cols = Booking.column_names
      expect(cols).to include("customer_id", "event_id", "status", "email", "confirmation", "phone", "created_at")
    end

    it "has non-null required fields" do
      booking = Booking.first
      expect(booking.customer_id).not_to be_nil
      expect(booking.status).to be_present
      expect(booking.email).to be_present
    end
  end
end
