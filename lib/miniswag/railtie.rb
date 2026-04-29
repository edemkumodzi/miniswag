# frozen_string_literal: true

require 'rails/railtie'

module Miniswag
  class Railtie < ::Rails::Railtie
    # Load Miniswag::TestCase lazily once ActionController has booted, so
    # ActionDispatch::IntegrationTest (and its dependencies) are available.
    # Loading test_case at gem-require time fails outside a Rails app because
    # action_dispatch/testing/integration depends on the full Rails testing
    # stack.
    ActiveSupport.on_load(:action_controller) do
      require 'miniswag/test_case'
    end

    rake_tasks do
      load File.expand_path('../tasks/miniswag_tasks.rake', __dir__)
    end

    generators do
      require 'generators/miniswag/install/install_generator'
    end
  end
end
