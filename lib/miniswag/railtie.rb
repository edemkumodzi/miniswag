# frozen_string_literal: true

module Miniswag
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load File.expand_path('../tasks/miniswag_tasks.rake', __dir__)
    end

    generators do
      require 'generators/miniswag/install/install_generator'
    end
  end
end
