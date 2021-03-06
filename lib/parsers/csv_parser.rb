# With CSV headers:
# Geocollider::CSVParser.new(
#   {
#     :separator => ",",
#     :quote_char => '"',
#     :headers => true,
#     :lat => "latitude",
#     :lon => "longitude",
#     :names => ["placename"],
#     :id => "identifier"
#   }
# )
#
# Without CSV headers:
# Geocollider::CSVParser.new(
#   {
#     :separator => "\t",
#     :quote_char => "\u{FFFF}",
#     :headers => false,
#     :lat => 4,
#     :lon => 5,
#     :names => [1,2],
#     :id => 0
#   }
# )

module Geocollider
  module Parsers
    class CSVParser
      extend Geocollider::Parser

      DEFAULT_OPTIONS = {
        :quote_char => "\u{FFFF}",
        :headers => false,
        :string_normalizer => lambda { |input| Geocollider::StringNormalizer.new(input).whitespace }
      }

      def initialize(options = {})
        @parse_options = DEFAULT_OPTIONS.merge(options)
        [:lat, :lon, :id].each do |param|
          if @parse_options[param].instance_of?(String) && @parse_options[param] =~ /\d+/
            @parse_options[param] = @parse_options[param].to_i
          end
        end
        if @parse_options.has_key?(:names)
          @parse_options[:names].map! do |name|
            if (!@parse_options[:headers]) && (name.instance_of?(String) && name =~ /\d+/)
              name.to_i
            else
              name
            end
          end
        end
      end

      def parse(filenames, compare = nil)
        names = {}
        places = {}

        filenames.each do |filename|
          csv_data = File.open(filename, "r:bom|utf-8")
          until csv_data.eof()
            csv_string = csv_data.read.force_encoding('UTF-8').encode('UTF-8', :invalid => :replace, :universal_newline => true)
            CSV.parse(csv_string, :headers => @parse_options[:headers], :col_sep => @parse_options[:separator], :quote_char => @parse_options[:quote_char]) do |row|
              csv_row = {}
              csv_row["id"] = row[@parse_options[:id]]

              # handle name-only parsing
              csv_place = nil
              unless @parse_options[:lat].nil? || @parse_options[:lon].nil? || ((@parse_options[:lat].class == String) && (@parse_options[:lat].empty?)) || ((@parse_options[:lon].class == String) && (@parse_options[:lon].empty?))
                csv_row["latitude"] = row[@parse_options[:lat]].to_f
                csv_row["longitude"] = row[@parse_options[:lon]].to_f
                csv_place = Geocollider::Point.new(latitude: csv_row["latitude"], longitude: csv_row["longitude"])
              end

              csv_names = []
              if @parse_options[:names] && (@parse_options[:names].length > 0) # handle point-only parsing
                csv_names = @parse_options[:names].map {|name_field| row[name_field]}.uniq.compact
              end

              if compare.nil? # no comparison function passed
                csv_names.each do |name|
                  normalized_name = @parse_options[:string_normalizer].call(name)
                  names[normalized_name] ||= []
                  names[normalized_namename] << csv_row["id"]
                end

                unless csv_place.nil?
                  places[csv_row["id"]] = {}
                  places[csv_row["id"]]["points"] ||= []
                  places[csv_row["id"]]["points"] << csv_place
                end
              else # comparison function passed
                if csv_names.length > 0
                  csv_names.each do |name|
                    compare.call(@parse_options[:string_normalizer].call(name), csv_place, csv_row["id"])
                  end
                else
                  compare.call(nil, csv_place, csv_row["id"])
                end
              end
            end
          end
        end

        return names, places
      end

      def string_comparison_lambda(names, places, csv_writer)
        lambda_function = lambda do |name, place, id|
          normalized_name = @parse_options[:string_normalizer].call(name)
          if names.has_key?(normalized_name)
            $stderr.puts "Name match for #{normalized_name}, writing all places"
            names[normalized_name].each do |matched_place|
              csv_writer << [matched_place, id]
            end
          end
        end
        return lambda_function
      end

      def point_comparison_lambda(names, places, csv_writer, distance_threshold = 8.0)
        lambda_function = lambda do |name, place, id|
          places.each_key do |check_place|
            if (places[check_place]['locationPrecision'] != 'unlocated')
              if places[check_place]['points']
                places[check_place]['points'].each do |check_point|
                  if Geocollider::Parsers::CSVParser.check_point(check_point, place, distance_threshold)
                    $stderr.puts "Match: #{check_place},#{id}"
                    csv_writer << [check_place, id]
                    break
                  end
                end
              end
            end
          end
        end
        return lambda_function
      end

      def comparison_lambda(names, places, csv_writer, distance_threshold = 8.0)
        lambda_function = lambda do |name, place, id|
          normalized_name = @parse_options[:string_normalizer].call(name)
          if names.has_key?(normalized_name)
            $stderr.puts "Name match for #{normalized_name}, checking places..."
            names[normalized_name].each do |check_place|
              $stderr.puts "Checking #{check_place}"
              places[check_place]['points'].each do |check_point|
                if Geocollider::Parsers::CSVParser.check_point(check_point, place, distance_threshold)
                  $stderr.puts "Match!"
                  csv_writer << [check_place, id]
                  break
                end
              end
            end
          end
        end
        return lambda_function
      end
    end
  end
end
