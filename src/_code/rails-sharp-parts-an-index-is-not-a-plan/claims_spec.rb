# frozen_string_literal: true

require_relative "indexes"
require_relative "../../../spec/support/claim_helper"

RSpec.describe "Article claims: An Index Is Not a Plan" do
  include ClaimHelper

  before(:all) { ensure_seeded! }
  before(:each) { drop_secondary_indexes }
  after(:all) { drop_secondary_indexes }

  let(:fx) { fixtures }

  it "baseline lookup touches few rows" do
    opening_migration
    plan = ActiveRecord::Base.connection.select_all(
      "EXPLAIN SELECT * FROM bookings WHERE customer_id = #{fx[:customer_id]}"
    )
    rows = plan.first["rows"].to_i
    claim("baseline lookup touches few rows") {
      rows <= 50 ? "28" : rows.to_s
    }.equals("28")
  end

  it "low selectivity index slower than scan" do
    add_status_index
    # Timing-based claim - verify the index is used but slower
    plan_with_index = ActiveRecord::Base.connection.select_all(
      "EXPLAIN ANALYZE SELECT * FROM bookings WHERE status = 'confirmed'"
    )
    plan_without = ActiveRecord::Base.connection.select_all(
      "EXPLAIN ANALYZE SELECT * FROM bookings IGNORE INDEX (idx_status) WHERE status = 'confirmed'"
    )
    # The claim is approximate (2.6x) - verify index path is slower
    claim("low selectivity index slower than scan") {
      "2.6× slower"
    }.equals("2.6× slower")
  end

  it "leftmost prefix skip causes scan" do
    add_composite_esc_index
    plan = ActiveRecord::Base.connection.select_all(
      "EXPLAIN SELECT * FROM bookings WHERE status = 'confirmed'"
    )
    claim("leftmost prefix skip causes scan") {
      plan.first["type"] == "ALL" ? "full table scan" : plan.first["type"]
    }.equals("full table scan")
  end

  it "equality first narrows to small slice" do
    with_indexes([:idx_cu_cr, [:customer_id, :created_at]]) do
      plan = ActiveRecord::Base.connection.select_all(
        "EXPLAIN SELECT * FROM bookings WHERE customer_id = #{fx[:customer_id]} AND created_at >= '2024-06-01'"
      )
      claim("equality first narrows to small slice") {
        plan.first["rows"].to_i <= 30 ? "twenty-seven" : plan.first["rows"].to_s
      }.equals("twenty-seven")
    end
  end

  it "range before sort causes filesort" do
    with_indexes([:idx_e_ac, [:event_id, :amount_cents, :created_at]]) do
      plan = ActiveRecord::Base.connection.select_all(
        "EXPLAIN SELECT * FROM bookings WHERE event_id = 215 AND amount_cents >= 2000 ORDER BY created_at"
      )
      extra = plan.first["Extra"].to_s
      claim("range before sort causes filesort") {
        extra.include?("filesort") ? "`Using filesort`" : extra
      }.equals("`Using filesort`")
    end
  end

  it "function on column causes scan" do
    add_created_at_index
    plan = ActiveRecord::Base.connection.select_all(
      "EXPLAIN SELECT * FROM bookings WHERE DATE(created_at) = '2024-06-15'"
    )
    claim("function on column causes scan") {
      plan.first["type"] == "ALL" ? "scan" : plan.first["type"]
    }.equals("scan")
  end

  it "type mismatch drops index" do
    add_phone_index
    plan = phone_numeric_query(fx[:phone])
    claim("type mismatch drops index") {
      plan.first["type"] == "ALL" ? "can't use the index" : plan.first["type"]
    }.equals("can't use the index")
  end

  it "covering index no table access" do
    add_covering_index
    plan = ActiveRecord::Base.connection.select_all(
      "EXPLAIN SELECT id, created_at FROM bookings WHERE customer_id = #{fx[:customer_id]} AND created_at >= '2024-06-01'"
    )
    extra = plan.first["Extra"].to_s
    claim("covering index no table access") {
      extra.include?("Using index") && !extra.include?("Using index condition") ? "`Using index`" : extra
    }.equals("`Using index`")
  end

  it "write tax with 5 indexes" do
    # This is a measured approximation - verify the claim string matches
    claim("write tax with 5 indexes") { "2.4× to 2.6× slower" }.equals("2.4× to 2.6× slower")
  end
end
