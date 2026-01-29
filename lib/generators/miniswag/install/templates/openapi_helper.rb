# frozen_string_literal: true

require 'test_helper'
require 'miniswag'

Miniswag.configure do |config|
  # Root folder where OpenAPI spec files will be generated
  config.openapi_root = Rails.root.join('openapi').to_s

  # Output format: :json or :yaml
  config.openapi_format = :json

  # Define one or more OpenAPI specs
  config.openapi_specs = {
    'v1/openapi.json' => {
      openapi: '3.0.1',
      info: {
        title: 'API V1',
        version: 'v1'
      },
      paths: {},
      servers: [
        { url: 'http://localhost:3000' }
      ]
    }
  }
end
