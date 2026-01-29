# frozen_string_literal: true

namespace :miniswag do
  desc 'Generate OpenAPI spec files from Minitest integration tests'
  task swaggerize: :environment do
    pattern = ENV.fetch('PATTERN', 'test/integration/**/*_test.rb')
    additional_opts = ENV.fetch('ADDITIONAL_OPTS', '')

    # Set the env var so the minitest plugin activates
    ENV['MINISWAG_GENERATE'] = '1'

    # Require the openapi_helper which configures Miniswag
    helper_path = Rails.root.join('test', 'openapi_helper.rb')
    require helper_path.to_s if File.exist?(helper_path)

    # Run minitest with the matching pattern
    args = [
      'bin/rails', 'test',
      *Dir.glob(pattern),
      additional_opts.presence
    ].compact

    system(*args) || abort('Miniswag: Test run failed')
  end
end

task miniswag: ['miniswag:swaggerize']
