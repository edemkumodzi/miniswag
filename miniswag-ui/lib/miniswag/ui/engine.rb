# frozen_string_literal: true

require 'miniswag/ui/middleware'
require 'miniswag/ui/basic_auth'

module Miniswag
  module Ui
    class Engine < ::Rails::Engine
      isolate_namespace Miniswag::Ui

      initializer 'miniswag-ui.initialize' do |app|
        middleware.use Miniswag::Ui::Middleware, Miniswag::Ui.config

        if Miniswag::Ui.config.basic_auth_enabled
          c = Miniswag::Ui.config
          app.middleware.use Miniswag::Ui::BasicAuth do |username, password|
            c.config_object[:basic_auth].values == [username, password]
          end
        end
      end
    end
  end
end
