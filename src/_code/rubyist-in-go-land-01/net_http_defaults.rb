#!/usr/bin/env ruby
# frozen_string_literal: true

require "net/http"

# segment: net-http-defaults
def net_http_defaults
  http = Net::HTTP.new("example.com")

  {
    open_timeout: http.open_timeout,
    read_timeout: http.read_timeout
  }
end
# end: net-http-defaults

if __FILE__ == $PROGRAM_NAME
  defaults = net_http_defaults
  puts "open_timeout: #{defaults[:open_timeout]}"
  puts "read_timeout: #{defaults[:read_timeout]}"
end
