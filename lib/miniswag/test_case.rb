# frozen_string_literal: true

require 'action_dispatch/testing/integration'
require 'miniswag/dsl'
require 'miniswag/request_factory'
require 'miniswag/response_validator'

module Miniswag
  class TestCase < ActionDispatch::IntegrationTest
    extend DSL

    class << self
      # Returns all test definitions registered via run_test! for OpenAPI generation
      def miniswag_test_definitions
        @_miniswag_test_definitions || []
      end
    end
  end
end
