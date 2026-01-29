# frozen_string_literal: true

require 'rails/generators'

module Miniswag
  module Ui
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      def add_initializer
        template('miniswag_ui.rb', 'config/initializers/miniswag_ui.rb')
      end

      def add_routes
        route("mount Miniswag::Ui::Engine => '/api-docs'")
      end
    end
  end
end
