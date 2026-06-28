# frozen_string_literal: true

require_relative "triage"

RSpec.describe "Ozymandias: Triage Model" do
  describe Symptom do
    let(:symptom) do
      Symptom.new(
        source: "Test symptom",
        kind: :error,
        reach: 100,
        reversible: true,
        severity: {customer: :major, financial: :moderate, developer: :minor, business: :none}
      )
    end

    it "computes weight from severity tier" do
      expect(symptom.weight(:customer)).to eq(50)
      expect(symptom.weight(:financial)).to eq(5)
      expect(symptom.weight(:developer)).to eq(1)
      expect(symptom.weight(:business)).to eq(0)
    end

    it "computes external score as (customer + financial) * reach" do
      expect(symptom.external).to eq((50 + 5) * 100)
    end

    it "computes internal score as (developer + business) * reach" do
      expect(symptom.internal).to eq((1 + 0) * 100)
    end

    it "reports escalate? based on reversibility" do
      expect(symptom.escalate?).to be(false)

      irreversible = Symptom.new(
        source: "Bad",
        kind: :integrity,
        reach: 1,
        reversible: false,
        severity: {customer: :severe, financial: :severe, developer: :major, business: :major}
      )
      expect(irreversible.escalate?).to be(true)
    end

    it "raises on unknown severity tier" do
      bad = Symptom.new(
        source: "Bad",
        kind: :error,
        reach: 1,
        reversible: true,
        severity: {customer: :catastrophic, financial: :none, developer: :none, business: :none}
      )
      expect { bad.weight(:customer) }.to raise_error(KeyError)
    end

    it "raises on unknown dimension" do
      expect { symptom.weight(:morale) }.to raise_error(KeyError)
    end
  end

  describe "#triage_example" do
    let(:output) { triage_example }

    it "produces the formatted ranking" do
      expect(output).to include("Reactive order")
      expect(output).to include("Proactive order")
    end

    it "ranks checkout latency first externally" do
      reactive = output.lines.select { |l| l.match?(/^\s+\d/) }
      expect(reactive.first).to include("Checkout#create p95 latency")
    end

    it "ranks reporting saturation higher internally than externally" do
      reactive = output.split("\n\n").first.lines.select { |l| l.match?(/^\s+\d/) }
      proactive = output.split("\n\n").last.lines.select { |l| l.match?(/^\s+\d/) }

      ext_rank = reactive.index { |l| l.include?("Reporting pool saturation") }
      int_rank = proactive.index { |l| l.include?("Reporting pool saturation") }

      expect(int_rank).to be < ext_rank
    end

    it "flags irreversible items with escalate" do
      expect(output).to include("Seats::DoubleBooking")
      expect(output).to include("<- irreversible")
    end
  end
end
