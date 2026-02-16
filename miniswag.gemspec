# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'miniswag/version'

Gem::Specification.new do |s|
  s.name        = 'miniswag'
  s.version     = Miniswag::VERSION
  s.authors     = ['Edem Kumodzi']
  s.email       = ['edem@sika.io']
  s.homepage    = 'https://github.com/edemkumodzi/miniswag'
  s.summary     = 'OpenAPI documentation DSL for Minitest — a drop-in replacement for rswag-specs'
  s.description = <<~DESC
    Write API integration tests in Minitest that simultaneously validate your API
    and generate OpenAPI 3.x specification files. Compatible with rswag-api and
    rswag-ui for serving docs and Swagger UI.
  DESC
  s.license = 'MIT'

  s.metadata = {
    'source_code_uri' => 'https://github.com/edemkumodzi/miniswag',
    'changelog_uri' => 'https://github.com/edemkumodzi/miniswag/blob/main/CHANGELOG.md',
    'rubygems_mfa_required' => 'true'
  }

  s.files = Dir['{lib}/**/*'] + %w[MIT-LICENSE Gemfile README.md]
  s.require_paths = ['lib']

  s.required_ruby_version = '>= 3.1'

  s.add_dependency 'actionpack', '>= 7.0', '< 9.0'
  s.add_dependency 'activesupport', '>= 7.0', '< 9.0'
  s.add_dependency 'json-schema', '>= 2.2', '< 7.0'
  s.add_dependency 'minitest', '>= 5.0', '< 7.0'
  s.add_dependency 'railties', '>= 7.0', '< 9.0'
end
