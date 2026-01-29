# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

Gem::Specification.new do |s|
  s.name        = 'miniswag-api'
  s.version     = ENV['RUBYGEMS_VERSION'] || '0.1.0'
  s.authors     = ['Edem Kumodzi']
  s.email       = ['edem@sika.io']
  s.homepage    = 'https://github.com/edemkumodzi/miniswag'
  s.summary     = 'A Rails Engine that exposes OpenAPI files as JSON/YAML endpoints'
  s.description = <<~DESC
    Open up your API to the OpenAPI ecosystem by exposing OpenAPI files,
    that describe your service, as JSON or YAML endpoints.
  DESC
  s.license = 'MIT'

  s.metadata = {
    'source_code_uri' => 'https://github.com/edemkumodzi/miniswag/tree/main/miniswag-api',
    'rubygems_mfa_required' => 'true'
  }

  s.files = Dir['{lib}/**/*'] + %w[MIT-LICENSE]
  s.require_paths = ['lib']

  s.required_ruby_version = '>= 3.1'

  s.add_dependency 'activesupport', '>= 7.0', '< 9.0'
  s.add_dependency 'railties', '>= 7.0', '< 9.0'
end
