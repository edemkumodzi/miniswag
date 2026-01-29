# frozen_string_literal: true

namespace :miniswag do
  desc 'Generate OpenAPI spec files from Minitest integration tests'
  task swaggerize: :environment do
    pattern = ENV.fetch('PATTERN', 'test/integration/**/*_test.rb')
    additional_opts = ENV.fetch('ADDITIONAL_OPTS', '')

    # Run minitest with the matching pattern
    # The miniswag plugin auto-generates specs after a green test run
    args = [
      'bin/rails', 'test',
      *Dir.glob(pattern),
      additional_opts.presence
    ].compact

    system(*args) || abort('Miniswag: Test run failed')
  end
end

task miniswag: ['miniswag:swaggerize']
