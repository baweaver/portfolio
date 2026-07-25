#!/usr/bin/env ruby
# frozen_string_literal: true

# segment: setup
# Fetches one Pokemon and prints its profile. Point POKEAPI_URL at a
# different server to use the live API or another mirror.
#
#   ruby pokemon.rb bulbasaur
#   POKEAPI_URL=https://pokeapi.co/api/v2 ruby pokemon.rb bulbasaur

require "json"
require "net/http"

BASE_URL = ENV.fetch("POKEAPI_URL", "http://localhost:9595/api/v2")

# Yes, I like my Perl-isms
query = ARGV.first or abort("usage: pokemon.rb NAME")

response = Net::HTTP.get_response(URI("#{BASE_URL}/pokemon/#{query.downcase}"))
abort("No Pokémon named #{query.inspect}") unless response.is_a?(Net::HTTPSuccess)

pokemon = JSON.parse(response.body, symbolize_names: true)
# end: setup

# segment: shape
pokemon => { id:, name:, types:, abilities:, stats: }
# end: shape

# segment: display
puts "##{id.to_s.rjust(4, '0')} #{name.capitalize}"
puts "Types:     #{types.sort_by { _1[:slot] }.map { _1.dig(:type, :name) }.join(' / ')}"
puts "Abilities: #{abilities.map { _1.dig(:ability, :name) }.join(', ')}"
puts

stats
  .map { [_1.dig(:stat, :name), _1[:base_stat]] }
  .sort_by(&:last)
  .reverse_each do |stat_name, base_stat|
    puts format("%-16s %3d %s", stat_name, base_stat, "█" * (base_stat / 5))
  end
# end: display
