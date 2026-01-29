# frozen_string_literal: true

require 'miniswag/version'
require 'miniswag/configuration'
require 'miniswag/railtie' if defined?(Rails::Railtie)

module Miniswag
  class << self
    def configure
      yield(config)
    end

    def config
      @config ||= Configuration.new
    end

    # Reset configuration (useful for testing)
    def reset!
      @config = nil
      @registered_test_classes = nil
    end

    # Registry of test classes that have miniswag test definitions.
    # Used by OpenapiGenerator to collect all metadata.
    def register_test_class(klass)
      registered_test_classes << klass unless registered_test_classes.include?(klass)
    end

    def registered_test_classes
      @registered_test_classes ||= []
    end
  end
end
