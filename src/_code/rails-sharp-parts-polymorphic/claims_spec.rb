# frozen_string_literal: true

require_relative "polymorphic"
require_relative "../../../spec/support/claim_helper"

RSpec.describe "Article claims: Polymorphic Type" do
  include ClaimHelper

  let(:seeds) { seed! }
  let(:event) { seeds[:event] }
  let(:proxy) { EventProxy.new(event) }

  it "proxy leak returns 3 rows" do
    claim("proxy leaks 3 rows") { Note.where(notable: proxy).count }.equals(3)
  end

  it "event.notes.count is 1" do
    claim("event notes count") { event.notes.count }.equals(1)
  end

  it "proxy find SQL has no notable_type" do
    sql = Note.where(notable: proxy).to_sql
    claim("proxy drops type") { sql.include?("notable_type") }.equals(false)
  end

  it "unwrap fix restores 1 row" do
    claim("unwrap returns 1") { Note.where(notable: proxy.__getobj__).count }.equals(1)
  end
end
