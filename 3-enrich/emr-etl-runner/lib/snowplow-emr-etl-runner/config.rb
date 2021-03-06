# Copyright (c) 2012-2013 SnowPlow Analytics Ltd. All rights reserved.
#
# This program is licensed to you under the Apache License Version 2.0,
# and you may not use this file except in compliance with the Apache License Version 2.0.
# You may obtain a copy of the Apache License Version 2.0 at http://www.apache.org/licenses/LICENSE-2.0.
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the Apache License Version 2.0 is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the Apache License Version 2.0 for the specific language governing permissions and limitations there under.

# Author::    Alex Dean (mailto:support@snowplowanalytics.com)
# Copyright:: Copyright (c) 2012-2013 SnowPlow Analytics Ltd
# License::   Apache License Version 2.0

require 'optparse'
require 'date'
require 'yaml'
require 'sluice'

# Config module to hold functions related to CLI argument parsing
# and config file reading to support the daily ETL job.
module SnowPlow
  module EmrEtlRunner
    module Config

      @@etl_implementations = Set.new(%w(hive hadoop))
      @@collector_formats = Set.new(%w(cloudfront clj-tomcat))
      @@storage_formats = Set.new(%w(hive redshift mysql-infobright))

      # TODO: would be nice to move this to using Kwalify
      # TODO: would be nice to support JSON as well as YAML

      # Return the configuration loaded from the supplied YAML file, plus
      # the additional constants above.
      def get_config()

        options = Config.parse_args()
        config = YAML.load_file(options[:config])

        # Add in the start and end dates, and our skip setting
        config[:start] = options[:start]
        config[:end] = options[:end]
        config[:skip] = options[:skip]

        # Generate our run ID: based on the time now
        config[:run_id] = Time.new.strftime("%Y-%m-%d-%H-%M-%S")

        unless options[:processbucket].nil?
          config[:s3][:buckets][:processing] = options[:processbucket]
        end

        # Add trailing slashes if needed to the non-nil buckets
        config[:s3][:buckets].reject{|k,v| v.nil?}.update(config[:s3][:buckets]){|k,v| Sluice::Storage::trail_slash(v)}

        # Validate the ETL implementation option
        unless @@etl_implementations.include?(config[:etl][:implementation]) 
          raise ConfigError, "etl_implementation '%s' not supported" % config[:etl][:implementation]
        end

        # Add the run ID to the output buckets (prevents collisions) if we using the Hadoop ETL
        if config[:etl][:implementation]
          # TODO
        end

        # Validate the collector format
        unless @@collector_formats.include?(config[:etl][:collector_format]) 
          raise ConfigError, "collector_format '%s' not supported" % config[:etl][:collector_format]
        end

        # Currently we only support start/end times for the CloudFront collector format. See #120 for details
        unless config[:etl][:collector_format] == 'cloudfront' or (config[:start].nil? and config[:end].nil?)
          raise ConfigError, "--start and --end date arguments are only supported if collector_format is 'cloudfront'"
        end

        # Construct path to our assets
        if config[:s3][:buckets][:assets] == "s3://snowplow-hosted-assets/"
          asset_host = "http://snowplow-hosted-assets.s3.amazonaws.com/" # Use the public S3 URL
        else
          asset_host = config[:s3][:buckets][:assets]
        end
        config[:maxmind_asset] = "%sthird-party/maxmind/GeoLiteCity.dat" % asset_host

        # Construct path to our ETL implementations
        asset_path = "%s3-enrich" % config[:s3][:buckets][:assets]

        # Construct path to our Hadoop ETL
        config[:hadoop_asset] = "%s/hadoop-etl/snowplow-hadoop-etl-%s.jar" % [asset_path, config[:snowplow][:hadoop_etl_version]]

        # Construct paths to our HiveQL and serde
        config[:serde_asset]  = "%s/hive-etl/serdes/snowplow-log-deserializers-%s.jar" % [asset_path, config[:snowplow][:serde_version]]

        unless @@storage_formats.include?(config[:etl][:storage_format])
          raise ConfigError, "storage_format '%s' not supported" % config[:etl][:storage_format]
        end
        storage_format_uscore = config[:etl][:storage_format].gsub("-", "_")
        storage_format_version_sym = "#{storage_format_uscore}_hiveql_version".to_sym
        config[:hiveql_asset] = "%s/hive-etl/hiveql/%s-etl-%s.q" % [
                                  asset_path, 
                                  config[:etl][:storage_format],
                                  config[:snowplow][storage_format_version_sym]
                                ]

        # Should we continue on unexpected error or not?
        continue_on = case config[:etl][:continue_on_unexpected_error]
                        when true
                          '1'
                        when false
                          '0'
                        else
                          raise ConfigError, "continue_on_unexpected_error '%s' not supported (only 'true' or 'false')" % config[:etl][:continue_on_unexpected_error]
                        end
        config[:etl][:continue_on_unexpected_error] = continue_on # Heinous mutability

        config
      end
      module_function :get_config

      private

      # Parse the command-line arguments
      # Returns: the hash of parsed options
      def parse_args()

        # Handle command-line arguments
        options = {}
        options[:skip] = []
        optparse = OptionParser.new do |opts|

          opts.banner = "Usage: %s [options]" % NAME
          opts.separator ""
          opts.separator "Specific options:"

          opts.on('-c', '--config CONFIG', 'configuration file') { |config| options[:config] = config }
          opts.on('-s', '--start YYYY-MM-DD', 'optional start date *') { |config| options[:start] = config }
          opts.on('-e', '--end YYYY-MM-DD', 'optional end date *') { |config| options[:end] = config }
          opts.on('-s', '--skip staging,emr,archive', Array, 'skip work step(s)') { |config| options[:skip] = config }
          opts.on('-b', '--process-bucket BUCKET', 'run emr only on specified bucket. Implies --skip staging,archive') { |config| 
            options[:processbucket] = config
            options[:skip] = %w(staging archive)
          }

          opts.separator ""
          opts.separator "* filters the raw event logs processed by EmrEtlRunner by their timestamp. Only"
          opts.separator "  supported with 'cloudfront' collector format currently."

          opts.separator ""
          opts.separator "Common options:"

          opts.on_tail('-h', '--help', 'Show this message') { puts opts; exit }
          opts.on_tail('-v', "--version", "Show version") do
            puts "%s %s" % [NAME, VERSION]
            exit
          end
        end

        # Run OptionParser's structural validation
        begin
          optparse.parse!
        rescue OptionParser::InvalidOption, OptionParser::MissingArgument
          raise ConfigError, "#{$!.to_s}\n#{optparse}"
        end

        # Check our skip argument
        options[:skip].each { |opt|
          unless %w(staging emr archive).include?(opt)
            raise ConfigError, "Invalid option: skip can be 'staging', 'emr' or 'archive', not '#{opt}'"
          end
        }

        # Check we have a config file argument
        if options[:config].nil?
          raise ConfigError, "Missing option: config\n#{optparse}"
        end

        # Check the config file exists
        unless File.file?(options[:config])
          raise ConfigError, "Configuration file '#{options[:config]}' does not exist, or is not a file."
        end

        # Finally check that start is before end, if both set
        if !options[:start].nil? and !options[:end].nil?
          if options[:start] > options[:end]
            raise ConfigError, "Invalid options: end date '#{options[:end]}' is before start date '#{options[:start]}'"
          end
        end

        options
      end
      module_function :parse_args

    end
  end
end