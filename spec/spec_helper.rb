require "simplecov"

SimpleCov.start do
  add_filter "/spec/"
  add_filter "_spec.rb"
  add_filter "/support/"
  enable_coverage :branch
  minimum_coverage line: 100, branch: 100
end

require_relative "support/claim_helper"
