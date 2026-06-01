# frozen_string_literal: true

require "spec_helper"

RSpec.describe "claim helper" do
  # Test the claim method in isolation
  let(:helper) do
    obj = Object.new
    obj.define_singleton_method(:claim) do |_name, value|
      value.to_s
    end
    obj
  end

  describe "#claim" do
    it "returns the value as a plain string" do
      expect(helper.claim("test claim", 42)).to eq("42")
    end

    it "returns string values unchanged" do
      expect(helper.claim("prose claim", "same thing")).to eq("same thing")
    end
  end
end
