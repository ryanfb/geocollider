begin
  require 'pbf_parser'
rescue LoadError
  # $stderr.puts 'Gem "pbf_parser" not installed - if you would like to use OSMPBFParser, run `bundle install --with osm` first'
end

module Geocollider
  module Parsers
    class OSMPBFParser
      extend Geocollider::Parser

      def compare(names, places, filenames, csv_writer)
        filenames.each do |filename|
          pbf = PbfParser.new(pbf_file)
          while pbf.next do
            pbf.ways.each {|way| way(way)}
          end
          while pbf.next do
            pbf.nodes.each {|node| node(node)}
            pbf.ways.each {|way| way(way)}
          end
        end
      end

      def way(way)
        way[:tags].keys.select{|t| t =~ /^name(:.+)?$/}.map{|t| way[:tags][t]}.each do |osm_name|
        end
      end
    end
  end
end
