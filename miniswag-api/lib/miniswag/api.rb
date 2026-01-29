# frozen_string_literal: true

require 'miniswag/api/configuration'
require 'miniswag/api/engine' if defined?(Rails::Engine)

module Miniswag
  module Api
    def self.configure
      yield(config)
    end

    def self.config
      @config ||= Configuration.new
    end
  end
end
