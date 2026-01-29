# Miniswag

OpenAPI (Swagger) documentation DSL for **Minitest**. A port of [rswag](https://github.com/rswag/rswag) that works with Minitest instead of RSpec.

Write API integration tests that simultaneously validate your API responses and generate OpenAPI 3.x specification files — no RSpec required.

## Gems

| Gem | Description |
|---|---|
| `miniswag` | Core DSL and OpenAPI spec generator (replaces `rswag-specs`) |
| `miniswag-api` | Rails engine that serves OpenAPI files as JSON/YAML endpoints (replaces `rswag-api`) |
| `miniswag-ui` | Rails engine that serves Swagger UI powered by your OpenAPI specs (replaces `rswag-ui`) |

## Installation

Add to your Gemfile:

```ruby
# Core — test DSL + spec generation
gem "miniswag", group: :test

# Optional — serve specs and Swagger UI in your app
gem "miniswag-api"
gem "miniswag-ui"
```

Then run:

```bash
bundle install
rails generate miniswag:install        # creates test/openapi_helper.rb
rails generate miniswag:api:install    # creates config/initializers/miniswag_api.rb
rails generate miniswag:ui:install     # creates config/initializers/miniswag_ui.rb
```

## Quick Start

### 1. Configure your OpenAPI specs

Edit `test/openapi_helper.rb`:

```ruby
require "miniswag"

Miniswag.configure do |config|
  config.openapi_root = Rails.root.join("docs/api").to_s

  config.openapi_specs = {
    "v1.yaml" => {
      openapi: "3.0.1",
      info: { title: "My API", version: "v1" },
      servers: [{ url: "https://api.example.com" }]
    }
  }
end
```

### 2. Write a test

```ruby
require "openapi_helper"

class PetsTest < Miniswag::TestCase
  path "/pets" do
    get "Lists all pets" do
      tags "Pets"
      produces "application/json"

      response 200, "successful" do
        schema type: :array, items: { "$ref" => "#/components/schemas/Pet" }

        run_test!
      end
    end

    post "Creates a pet" do
      tags "Pets"
      consumes "application/json"
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          age: { type: :integer }
        },
        required: %w[name]
      }

      response 201, "pet created" do
        params { { body: { name: "Fido", age: 3 } } }

        run_test!
      end

      response 422, "invalid request" do
        params { { body: { age: -1 } } }

        run_test!
      end
    end
  end
end
```

### 3. Generate OpenAPI specs

```bash
rake miniswag:swaggerize
```

This runs your tests and writes the resulting OpenAPI files to `openapi_root`.

## DSL Reference

The DSL mirrors rswag closely. Key differences from rswag are noted below.

### Structure

```ruby
class MyTest < Miniswag::TestCase
  openapi_spec "admin.yaml"          # target a specific spec file

  path "/resources/{id}" do
    get "Fetch a resource" do
      response 200, "success" do
        run_test!
      end
    end
  end
end
```

### Parameters

```ruby
parameter name: :id, in: :path, type: :integer
parameter name: :status, in: :query, type: :string
parameter name: "X-Request-Id", in: :header, type: :string
parameter name: :body, in: :body, schema: { type: :object, properties: { ... } }
```

Path parameters are automatically marked `required: true`.

### Providing parameter values

Instead of rswag's `let` blocks, use `params`:

```ruby
response 200, "success" do
  params { { id: @resource.id, status: "active" } }
  run_test!
end
```

### Setup (replacing `let!` / `before`)

```ruby
response 200, "success" do
  before { @resource = create_resource(name: "test") }
  params { { id: @resource.id } }
  run_test!
end
```

### Custom assertions after the request

```ruby
run_test! do |response|
  data = JSON.parse(response.body)
  assert_equal "test", data["name"]
end
```

### Operation attributes

```ruby
get "Fetch resource" do
  tags "Resources"
  operationId "getResource"
  description "Returns a single resource by ID"
  consumes "application/json"
  produces "application/json"
  security [{ bearer: [] }]
  deprecated true
end
```

### Response schema & headers

```ruby
response 200, "success" do
  schema type: :object, properties: { id: { type: :integer } }
  header "X-Rate-Limit", type: :integer, description: "Requests per hour"
  run_test!
end
```

### Request body examples

```ruby
post "Create resource" do
  request_body_example value: { name: "example" }, summary: "Basic example"
  # ...
end
```

### Metadata (custom extensions)

```ruby
response 200, "success" do
  metadata[:operation] ||= {}
  metadata[:operation]["x-public-docs"] = true
  run_test!
end
```

## Migrating from rswag

| rswag (RSpec) | miniswag (Minitest) |
|---|---|
| `RSpec.describe "...", type: :request do` | `class MyTest < Miniswag::TestCase` |
| `let(:Authorization) { "Bearer ..." }` | `params { { Authorization: "Bearer ..." } }` |
| `let!(:resource) { create(:resource) }` | `before { @resource = create(:resource) }` |
| `let(:id) { resource.id }` | include in `params` block |
| `let(:body) { { name: "x" } }` | include in `params` block |
| `openapi_spec:` metadata on describe | `openapi_spec "name.yaml"` at class level |
| `require "swagger_helper"` | `require "openapi_helper"` |

## Configuration

```ruby
Miniswag.configure do |config|
  # Required — where to write generated spec files
  config.openapi_root = Rails.root.join("docs/api").to_s

  # Required — spec definitions (supports multiple files)
  config.openapi_specs = { "v1.yaml" => { openapi: "3.0.1", info: { ... } } }

  # Optional — output format (:json or :yaml, default :yaml)
  config.openapi_format = :yaml

  # Optional — strict schema validation (rejects additional properties)
  config.openapi_strict_schema_validation = false
end
```

## Requirements

- Ruby >= 3.1
- Rails >= 7.0, < 9.0
- Minitest ~> 5.0

## License

MIT. See [MIT-LICENSE](MIT-LICENSE).
