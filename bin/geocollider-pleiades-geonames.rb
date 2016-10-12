#!/usr/bin/env ruby
#
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require 'geocollider'

pleiades = Geocollider::PleiadesParser.new()
names, places = pleiades.parse(%w{pleiades-places-latest.csv pleiades-names-latest.csv pleiades-locations-latest.csv})
$stderr.puts names.first.inspect
$stderr.puts places.first.inspect
$stderr.puts names.keys.length
$stderr.puts places.keys.length

geonames = Geocollider::GeonamesParser.new()
CSV.open(ARGV[0], "wb") do |csv|
  # geonames.compare(names, places, ARGV[1..-1], csv)
  geonames_compare = geonames.comparison_lambda(names, places, csv)
  geonames.parse(ARGV[1..-1], geonames_compare)
end
