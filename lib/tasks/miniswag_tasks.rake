# frozen_string_literal: true

namespace :miniswag do
  desc 'Generate OpenAPI spec files from Minitest integration tests'
  task swaggerize: :environment do
    pattern = ENV.fetch('PATTERN', 'test/integration/**/*_test.rb')
    additional_opts = ENV.fetch('ADDITIONAL_OPTS', '')

    # Set the env var so the minitest plugin activates in the subprocess
    ENV['MINISWAG_GENERATE'] = '1'

    # Run minitest with the matching pattern
    # The openapi_helper is loaded by the test files themselves via require "openapi_helper"
    args = [
      'bin/rails', 'test',
      *Dir.glob(pattern),
      additional_opts.presence
    ].compact

    system(*args) || abort('Miniswag: Test run failed')
  end
end

task miniswag: ['miniswag:swaggerize']
