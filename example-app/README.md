# miniswag Todo Example App

A minimal Rails API application demonstrating [miniswag](https://github.com/edemkumodzi/miniswag) — OpenAPI documentation generated directly from Minitest integration tests.

This app is the companion example for the miniswag gem, the same role that `test-app` plays in rswag.

## What's in this app?

A simple **Todos API** with:

| Endpoint | Description |
|----------|-------------|
| `GET /api/v1/todos` | List all todos (with optional `?completed=true/false` filter) |
| `POST /api/v1/todos` | Create a todo |
| `GET /api/v1/todos/:id` | Fetch a single todo |
| `PATCH /api/v1/todos/:id` | Update a todo |
| `DELETE /api/v1/todos/:id` | Delete a todo |

## Setup

```bash
git clone https://github.com/edemkumodzi/miniswag
cd miniswag/example-app

bundle install
bin/rails db:create db:migrate

# Run the API
bin/rails server
```

## Generate OpenAPI docs

```bash
# Run miniswag tests and write docs/api/v1.yaml
rake miniswag:swaggerize
```

Then start the server and visit `/api-docs` to browse the Swagger UI.

## Run tests only (without generating docs)

```bash
bin/rails test test/api
```

## Project structure

```
├── app/
│   ├── controllers/api/v1/
│   │   └── todos_controller.rb
│   └── models/
│       └── todo.rb
├── config/
│   ├── initializers/
│   │   ├── miniswag_api.rb         # Serve OpenAPI JSON/YAML endpoints
│   │   └── miniswag_ui.rb          # Serve Swagger UI
│   └── routes.rb
├── db/
│   └── migrate/
│       └── *_create_todos.rb
├── docs/api/
│   └── v1.yaml                     # Generated — do not edit by hand
├── test/
│   ├── openapi_helper.rb           # miniswag configuration
│   ├── support/
│   │   └── todo_helpers.rb         # Shared test helpers
│   └── api/v1/
│       └── todos_test.rb           # miniswag DSL tests → generates v1.yaml
└── lib/tasks/
    └── miniswag.rake               # (provided by the gem, listed for clarity)
```