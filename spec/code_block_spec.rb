# frozen_string_literal: true

require "spec_helper"
require "bridgetown"
require "rouge"

module Shared; end
require_relative "../src/_components/shared/code_block"

RSpec.describe Shared::CodeBlock do
  let(:file) { "beyond-enumerable-windows/rivulet.rb" }

  before do
    site = double("site", source: File.expand_path("../src", __dir__))
    allow(Bridgetown::Current).to receive(:site).and_return(site)
  end

  describe "segment extraction" do
    it "extracts a named segment" do
      block = described_class.new(file: file, segment: "enumerable_sum")
      html = block.highlighted

      expect(html).to include("select")
      expect(html).not_to include("# segment:")
    end

    it "excludes other segments" do
      block = described_class.new(file: file, segment: "imperative_sum")
      html = block.highlighted

      expect(html).to include("for")
      expect(html).not_to include("select")
    end

    it "extracts all segments when no segment specified" do
      block = described_class.new(file: file)
      html = block.highlighted

      expect(html).to include("Window")
      expect(html).to include("Rivulet")
      expect(html).not_to include("# segment:")
    end
  end

  describe "unwrap: true" do
    it "strips the def/end wrapper" do
      block = described_class.new(file: file, segment: "imperative_sum", unwrap: true)
      html = block.highlighted

      expect(html).not_to include("def")
      expect(html).to include("sum")
    end

    it "de-indents the body to column 0" do
      block = described_class.new(file: file, segment: "enumerable_sum", unwrap: true)
      html = block.highlighted

      expect(html).not_to start_with(" ")
    end

    it "is a no-op for non-method segments" do
      block = described_class.new(file: file, segment: "window_class", unwrap: true)
      html = block.highlighted

      expect(html).to include("Window")
    end

    it "handles a single-line segment" do
      block = described_class.new(file: file, segment: "enumerable_sum", unwrap: true)
      html = block.highlighted

      # Single expression, no trailing end to pop
      expect(html).not_to include("def")
    end
  end

  describe "missing file" do
    it "returns a not-found comment" do
      block = described_class.new(file: "nonexistent/file.rb", segment: "foo")
      html = block.highlighted

      expect(html).to include("File not found")
    end
  end

  describe "edge cases" do
    let(:fixture) { "test-fixtures/edges.rb" }

    it "unwrap is a no-op when segment has no def or end" do
      block = described_class.new(file: fixture, segment: "bare_expression", unwrap: true)
      html = block.highlighted

      expect(html).to include("x")
    end

    it "handles an empty segment" do
      block = described_class.new(file: fixture, segment: "empty", unwrap: true)
      html = block.highlighted

      expect(html).to eq("")
    end
  end
end
