# frozen_string_literal: true

require 'minitest/autorun'
require 'miniswag'
require 'miniswag/configuration'
require 'miniswag/request_factory'
require 'miniswag/response_validator'
require 'miniswag/extended_schema'
require 'miniswag/dsl'
require 'miniswag/openapi_generator'
# NOTE: miniswag/test_case requires ActionDispatch::IntegrationTest
# which is only available inside a Rails app. It is not loaded here.
