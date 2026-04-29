# frozen_string_literal: true

require "test_helper"
require "miniswag"
require "miniswag/test_case"

Miniswag.configure do |config|
  # Root folder where OpenAPI spec files will be generated
  config.openapi_root = Rails.root.join("docs/api").to_s

  # Output format: :json or :yaml
  config.openapi_format = :json

  # Define one or more OpenAPI specs
  config.openapi_specs = {
    "v1/openapi.json" => {
      openapi: "3.0.1",
      info: {
        title: "Todo API",
        version: "v1"
      },
      paths: {},
      servers: [
        { url: "http://localhost:3000" }
      ],
      components: {
        schemas: {
          Todo: {
            type: :object,
            properties: {
              id: { type: :integer },
              title: { type: :string },
              completed: { type: :boolean },
              created_at: { type: :string, format: "date-time" },
              updated_at: { type: :string, format: "date-time" }
            },
            required: %w[id title completed created_at updated_at]
          },
          TodoInput: {
            type: :object,
            properties: {
              title: { type: :string },
              completed: { type: :boolean }
            },
            required: %w[title]
          },
          ErrorResponse: {
            type: :object,
            properties: {
              errors: {
                type: :array,
                items: { type: :string }
              }
            },
            required: %w[errors]
          },
          NotFoundError: {
            type: :object,
            properties: {
              error: { type: :string }
            },
            required: %w[error]
          }
        }
      }
    }
  }
end
