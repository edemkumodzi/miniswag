# frozen_string_literal: true

require 'rails/generators'

module Miniswag
  module Api
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      def add_initializer
        template('miniswag_api.rb', 'config/initializers/miniswag_api.rb')
      end

      def add_routes
        route("mount Miniswag::Api::Engine => '/api-docs'")
      end
    end
  end
end
