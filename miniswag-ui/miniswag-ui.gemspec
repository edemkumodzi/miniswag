# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

Gem::Specification.new do |s|
  s.name        = 'miniswag-ui'
  s.version     = ENV['RUBYGEMS_VERSION'] || '0.1.0'
  s.authors     = ['Edem Kumodzi']
  s.email       = ['edem@sika.io']
  s.homepage    = 'https://github.com/edemkumodzi/miniswag'
  s.summary     = 'A Rails Engine that includes swagger-ui and powers it from configured OpenAPI endpoints'
  s.description = <<~DESC
    Generate beautiful API documentation, including a UI to explore and test
    operations, directly from your Minitest integration tests.
  DESC
  s.license = 'MIT'

  s.metadata = {
    'source_code_uri' => 'https://github.com/edemkumodzi/miniswag/tree/main/miniswag-ui',
    'rubygems_mfa_required' => 'true'
  }

  s.files = Dir.glob('{lib,node_modules}/**/*') + %w[MIT-LICENSE]
  s.require_paths = ['lib']

  s.required_ruby_version = '>= 3.1'

  s.add_dependency 'actionpack', '>= 7.0', '< 9.0'
  s.add_dependency 'railties', '>= 7.0', '< 9.0'
end
