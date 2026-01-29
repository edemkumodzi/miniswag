# frozen_string_literal: true

require 'miniswag/ui/configuration'
require 'miniswag/ui/engine'

module Miniswag
  module Ui
    def self.configure
      yield(config)
    end

    def self.config
      @config ||= Configuration.new
    end
  end
end
