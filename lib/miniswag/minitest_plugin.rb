# frozen_string_literal: true

require 'minitest'

module Minitest
  # Minitest plugin that triggers OpenAPI generation after the test suite.
  # Activated by setting MINISWAG_GENERATE=1 or via the rake task.
  def self.plugin_miniswag_init(options)
    return unless ENV['MINISWAG_GENERATE'] == '1'

    reporter << Miniswag::Reporter.new(options[:io], options)
  end

  def self.plugin_miniswag_options(opts, _options)
    opts.on '--miniswag-generate', 'Generate OpenAPI specs after test run' do
      ENV['MINISWAG_GENERATE'] = '1'
    end
  end
end

module Miniswag
  class Reporter < Minitest::StatisticsReporter
    def report
      super
      return if errors > 0 || failures > 0

      puts 'Miniswag: Generating OpenAPI specs...'
      require 'miniswag/openapi_generator'
      generator = Miniswag::OpenapiGenerator.new
      generator.generate!
    end
  end
end
