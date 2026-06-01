# frozen_string_literal: true

require "spec_helper"

RSpec.describe "scripts/verify_claims.rb" do
  let(:script) { File.expand_path("../scripts/verify_claims.rb", __dir__) }

  it "passes when all claims have specs" do
    output = `ruby #{script} 2>&1`
    expect($?.exitstatus).to eq(0)
    expect(output).to include("All")
    expect(output).to include("claims have corresponding specs")
  end

  it "fails when a claim is missing a spec" do
    # Create a temp post with an unmatched claim
    tmp_post = File.expand_path("../src/_posts/9999-01-01-test-claim.md", __dir__)
    File.write(tmp_post, '<%= claim("totally fake unmatched claim", "nope") %>')

    output = `ruby #{script} 2>&1`
    status = $?.exitstatus

    File.delete(tmp_post)

    expect(status).to eq(1)
    expect(output).to include("totally fake unmatched claim")
  end
end
