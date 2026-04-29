#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to run miniswag tests and generate OpenAPI specs

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "miniswag/openapi_generator"

# Load the test to register the test class
require_relative "../test/integration/api/v1/todos_test"

# Now generate the OpenAPI specs
generator = Miniswag::OpenapiGenerator.new
generator.generate!

puts "OpenAPI specs generated successfully!"
