# frozen_string_literal: true

module Miniswag
  class Configuration
    attr_accessor :openapi_root, :openapi_specs, :openapi_format,
                  :openapi_all_properties_required, :openapi_no_additional_properties,
                  :dry_run

    def initialize
      @openapi_root = nil
      @openapi_specs = {}
      @openapi_format = :json
      @openapi_all_properties_required = false
      @openapi_no_additional_properties = false
      @dry_run = ENV.key?('MINISWAG_DRY_RUN') ? ENV['MINISWAG_DRY_RUN'] == '1' : true
    end

    def get_openapi_spec(name)
      return openapi_specs.values.first if name.nil?
      raise ConfigurationError, "Unknown openapi_spec '#{name}'" unless openapi_specs[name]

      openapi_specs[name]
    end

    def validate!
      raise ConfigurationError, 'No openapi_root provided. See openapi_helper.rb' if openapi_root.nil?
      if openapi_specs.nil? || openapi_specs.empty?
        raise ConfigurationError, 'No openapi_specs defined. See openapi_helper.rb'
      end
      return if %i[json yaml].include?(openapi_format)

      raise ConfigurationError, "Unknown openapi_format '#{openapi_format}'"
    end
  end

  class ConfigurationError < StandardError; end
end
