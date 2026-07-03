# frozen_string_literal: true

# segment: triage_model
TIER = {
  none: 0,
  minor: 1,
  moderate: 5,
  major: 50,
  severe: 500
}.freeze

Symptom = Data.define(:source, :kind, :reach, :severity, :reversible) do
  def weight(dimension) = TIER.fetch(severity.fetch(dimension))

  def external = (weight(:customer) + weight(:financial)) * reach

  def internal = (weight(:developer) + weight(:business)) * reach

  def escalate? = !reversible
end
# end: triage_model

# segment: triage_example
def triage_example
  symptoms = [
    Symptom.new(
      source: "Checkout#create p95 latency",
      kind: :latency,
      reach: 2400,
      reversible: true,
      severity: {customer: :major, financial: :major, developer: :moderate, business: :moderate}
    ),
    Symptom.new(
      source: "SeatMap#show p95 latency",
      kind: :latency,
      reach: 3100,
      reversible: true,
      severity: {customer: :major, financial: :moderate, developer: :moderate, business: :minor}
    ),
    Symptom.new(
      source: "Checkout::PaymentTimeout",
      kind: :error,
      reach: 295,
      reversible: true,
      severity: {customer: :major, financial: :major, developer: :moderate, business: :moderate}
    ),
    Symptom.new(
      source: "Seats::DoubleBooking",
      kind: :integrity,
      reach: 23,
      reversible: false,
      severity: {customer: :severe, financial: :severe, developer: :major, business: :major}
    ),
    Symptom.new(
      source: "Reporting pool saturation",
      kind: :saturation,
      reach: 40,
      reversible: true,
      severity: {customer: :moderate, financial: :moderate, developer: :severe, business: :major}
    ),
    Symptom.new(
      source: "Orders::ConfirmationEmailFailure",
      kind: :error,
      reach: 520,
      reversible: true,
      severity: {customer: :moderate, financial: :none, developer: :minor, business: :none}
    ),
    Symptom.new(
      source: "EventSearch::FilterError",
      kind: :error,
      reach: 1800,
      reversible: true,
      severity: {customer: :minor, financial: :none, developer: :minor, business: :none}
    ),
    Symptom.new(
      source: "Events::AdminImageUpload",
      kind: :error,
      reach: 4,
      reversible: true,
      severity: {customer: :minor, financial: :none, developer: :minor, business: :none}
    ),
  ]

  lines = []

  lines << "Reactive order: what customers and revenue feel now"
  symptoms.sort_by { |s| -s.external }.each_with_index do |s, i|
    flag = s.escalate? ? "   <- irreversible" : ""
    lines << format(" %d. %-37s ext %7d   int %7d%s", i + 1, s.source, s.external, s.internal, flag)
  end

  lines << ""
  lines << "Proactive order: what engineers and the business carry"
  symptoms.sort_by { |s| -s.internal }.each_with_index do |s, i|
    flag = s.escalate? ? "   <- irreversible" : ""
    lines << format(" %d. %-37s int %7d   ext %7d%s", i + 1, s.source, s.internal, s.external, flag)
  end

  lines.join("\n")
end
# end: triage_example
