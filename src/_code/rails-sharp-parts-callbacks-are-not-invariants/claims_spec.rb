# frozen_string_literal: true

require_relative "callbacks"
require_relative "../../../spec/support/claim_helper"

RSpec.describe "Article claims: Callbacks Are Not Invariants" do
  include ClaimHelper

  it "counter cache isn't healed on next update" do
    event = Event.create!(name: "ClaimTest#{SecureRandom.hex(4)}")
    Seat.create!(event: event, external_ref: "CL1#{SecureRandom.hex(4)}")
    Seat.insert_all([{event_id: event.id, external_ref: "CL2#{SecureRandom.hex(4)}"}])
    Seat.where(event_id: event.id).first.update!(reserved_by: "someone")

    claim("counter cache isn't healed on next update") {
      event.reload.seats_count
    }.equals(1)
  end
end
