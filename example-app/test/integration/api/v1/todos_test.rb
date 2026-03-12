# frozen_string_literal: true

require "openapi_helper"

class ApiV1TodosTest < Miniswag::TestCase
  openapi_spec "v1/openapi.json"

  path "/api/v1/todos" do
    get "List all todos" do
      tags "Todos"
      operationId "listTodos"
      description "Returns a list of all todos. Optionally filter by completion status."
      produces "application/json"

      parameter name: :completed,
                in: :query,
                schema: { type: :boolean },
                required: false,
                description: "Filter todos by completion status"

      response 200, "successful" do
        schema type: :array, items: { "$ref" => "#/components/schemas/Todo" }

        run_test! do |response|
          data = JSON.parse(response.body)
          assert data.is_a?(Array)
          assert data.all? { |todo| todo.key?("id") && todo.key?("title") }
        end
      end

      response 200, "filtered by completed=true", focus: true do
        params { { completed: true } }
        schema type: :array, items: { "$ref" => "#/components/schemas/Todo" }

        before do
          Todo.create!(title: "Completed task", completed: true)
          Todo.create!(title: "Incomplete task", completed: false)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          assert data.all? { |todo| todo["completed"] == true }
        end
      end

      response 200, "filtered by completed=false", focus: true do
        params { { completed: false } }
        schema type: :array, items: { "$ref" => "#/components/schemas/Todo" }

        before do
          Todo.create!(title: "Completed task", completed: true)
          Todo.create!(title: "Incomplete task", completed: false)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          assert data.all? { |todo| todo["completed"] == false }
        end
      end
    end

    post "Create a todo" do
      tags "Todos"
      operationId "createTodo"
      description "Creates a new todo item"
      consumes "application/json"
      produces "application/json"

      parameter name: :todo,
                in: :body,
                schema: {
                  type: :object,
                  properties: {
                    todo: { "$ref" => "#/components/schemas/TodoInput" }
                  },
                  required: %w[todo]
                }

      request_body_example value: { todo: { title: "New task", completed: false } },
                           summary: "Create a new todo"

      request_body_example value: { todo: { title: "Completed task", completed: true } },
                           summary: "Create a completed todo"

      response 201, "todo created" do
        params { { todo: { title: "Buy groceries", completed: false } } }
        schema "$ref" => "#/components/schemas/Todo"

        run_test! do |response|
          data = JSON.parse(response.body)
          assert_equal "Buy groceries", data["title"]
          assert_equal false, data["completed"]
          assert response.headers["Location"].include?("/api/v1/todos/")
        end
      end

      response 422, "invalid request" do
        params { { todo: { title: "", completed: false } } }
        schema "$ref" => "#/components/schemas/ErrorResponse"

        run_test! do |response|
          data = JSON.parse(response.body)
          assert data["errors"].any? { |error| error.include?("Title") }
        end
      end

      response 400, "missing todo parameter" do
        params { { todo: {} } }
        schema type: :object, properties: { error: { type: :string } }

        run_test! do |response|
          data = JSON.parse(response.body)
          assert data["error"].present? || data["status"] == 400
        end
      end
    end
  end

  path "/api/v1/todos/{id}" do
    parameter name: :id, in: :path, type: :integer, description: "Todo ID"

    get "Get a todo" do
      tags "Todos"
      operationId "getTodo"
      description "Returns a single todo by ID"
      produces "application/json"

      response 200, "successful" do
        before { @todo = Todo.create!(title: "Test todo", completed: false) }
        params { { id: @todo.id } }
        schema "$ref" => "#/components/schemas/Todo"

        run_test! do |response|
          data = JSON.parse(response.body)
          assert_equal @todo.id, data["id"]
          assert_equal "Test todo", data["title"]
        end
      end

      response 404, "todo not found" do
        params { { id: 999_999 } }
        schema "$ref" => "#/components/schemas/NotFoundError"

        run_test! do |response|
          data = JSON.parse(response.body)
          assert_equal "Todo not found", data["error"]
        end
      end
    end

    patch "Update a todo" do
      tags "Todos"
      operationId "updateTodo"
      description "Updates an existing todo"
      consumes "application/json"
      produces "application/json"

      parameter name: :todo,
                in: :body,
                schema: {
                  type: :object,
                  properties: {
                    todo: { "$ref" => "#/components/schemas/TodoInput" }
                  }
                }

      request_body_example value: { todo: { title: "Updated title" } },
                           summary: "Update todo title"

      request_body_example value: { todo: { completed: true } },
                           summary: "Mark todo as completed"

      response 200, "successful" do
        before { @todo = Todo.create!(title: "Original title", completed: false) }
        params { { id: @todo.id, todo: { title: "Updated title", completed: true } } }
        schema "$ref" => "#/components/schemas/Todo"

        run_test! do |response|
          data = JSON.parse(response.body)
          assert_equal "Updated title", data["title"]
          assert_equal true, data["completed"]
        end
      end

      response 422, "invalid request" do
        before { @todo = Todo.create!(title: "Valid title", completed: false) }
        params { { id: @todo.id, todo: { title: "" } } }
        schema "$ref" => "#/components/schemas/ErrorResponse"

        run_test! do |response|
          data = JSON.parse(response.body)
          assert data["errors"].any? { |error| error.include?("Title") }
        end
      end

      response 404, "todo not found" do
        params { { id: 999_999, todo: { title: "New title" } } }
        schema "$ref" => "#/components/schemas/NotFoundError"

        run_test! do |response|
          data = JSON.parse(response.body)
          assert_equal "Todo not found", data["error"]
        end
      end
    end

    delete "Delete a todo" do
      tags "Todos"
      operationId "deleteTodo"
      description "Deletes a todo item"

      response 204, "successful" do
        before { @todo = Todo.create!(title: "Todo to delete", completed: false) }
        params { { id: @todo.id } }

        run_test! do |response|
          assert_equal 204, response.status
          assert response.body.blank?
          assert_nil Todo.find_by(id: @todo.id)
        end
      end

      response 404, "todo not found" do
        params { { id: 999_999 } }
        schema "$ref" => "#/components/schemas/NotFoundError"

        run_test! do |response|
          data = JSON.parse(response.body)
          assert_equal "Todo not found", data["error"]
        end
      end
    end
  end
end
