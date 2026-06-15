# frozen_string_literal: true

require_relative "queries"
require_relative "../../../spec/support/claim_helper"

RSpec.describe "Article claims: Queries, Read Models, and Batching" do
  include ClaimHelper

  before(:each) { seed! }

  it "the_leak reserves all 12 seats" do
    claim("the_leak reserves all seats") { the_leak[:reserved_after] }.equals(12)
  end

  it "lazy_fanout fires 12 queries" do
    claim("lazy fanout fires N queries") { lazy_fanout }.equals(12)
  end

  it "n_plus_one_demo fires 12 queries (one per seat)" do
    claim("n+1 fires one query per seat") { n_plus_one_demo }.equals(12)
  end

  it "batched_demo fires 1 query" do
    claim("batched fires 1 query") { batched_demo }.equals(1)
  end

  it "naive composite fires 36 queries (3 per seat)" do
    claim("naive composite fires 3*N queries") { reservation_views_naive_demo }.equals(36)
  end

  it "batched composite fires 3 queries" do
    claim("batched composite fires 3 queries") { reservation_views_batched_demo }.equals(3)
  end

  it "batch loader placeholder creation fires 0 queries" do
    BatchLoader::Executor.ensure_current
    claim("batch loader placeholder fires 0 queries") { batch_loader_demo[:placeholder_count] }.equals(0)
  end

  it "batch loader resolution fires 1 query" do
    BatchLoader::Executor.ensure_current
    claim("batch loader resolve fires 1 query") { batch_loader_demo[:resolve_count] }.equals(1)
  end
end
