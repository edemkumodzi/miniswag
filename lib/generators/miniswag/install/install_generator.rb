# frozen_string_literal: true

require 'rails/generators'

module Miniswag
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path('templates', __dir__)

    def copy_openapi_helper
      template('openapi_helper.rb', 'test/openapi_helper.rb')
    end
  end
end
