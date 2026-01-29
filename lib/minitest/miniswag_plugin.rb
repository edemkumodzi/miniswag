# frozen_string_literal: true

require 'minitest'

module Minitest
  # Minitest plugin that triggers OpenAPI generation after the test suite.
  # Always active — generates specs after every green test run.
  # Set MINISWAG_DRY_RUN=1 to skip generation.
  def self.plugin_miniswag_init(options)
    return if ENV['MINISWAG_DRY_RUN'] == '1'

    reporter << Miniswag::Reporter.new(options[:io], options)
  end

  def self.plugin_miniswag_options(opts, _options)
    opts.on '--no-miniswag', 'Skip OpenAPI spec generation after test run' do
      ENV['MINISWAG_DRY_RUN'] = '1'
    end
  end
end

module Miniswag
  class Reporter < Minitest::StatisticsReporter
    def report
      super
      return if errors > 0 || failures > 0
      return if Miniswag.registered_test_classes.empty?
      return unless Miniswag.config.openapi_root && Miniswag.config.openapi_specs&.any?

      puts 'Miniswag: Generating OpenAPI specs...'
      require 'miniswag/openapi_generator'
      generator = Miniswag::OpenapiGenerator.new
      generator.generate!
    end
  end
end
