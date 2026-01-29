# frozen_string_literal: true

require 'miniswag/api/middleware'

module Miniswag
  module Api
    class Engine < ::Rails::Engine
      isolate_namespace Miniswag::Api

      initializer 'miniswag-api.initialize' do |_app|
        middleware.use Miniswag::Api::Middleware, Miniswag::Api.config
      end
    end
  end
end
