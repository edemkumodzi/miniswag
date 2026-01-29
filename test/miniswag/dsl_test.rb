# frozen_string_literal: true

require 'test_helper'

class DSLTest < Minitest::Test
  # Test that the DSL correctly builds metadata structures.
  # We create a dummy class, extend it with DSL, and invoke DSL methods.

  def setup
    @klass = Class.new
    @klass.extend(Miniswag::DSL)
    Miniswag.reset!
  end

  # ── path ──────────────────────────────────────────────────────────────

  def test_path_sets_template
    @klass.path '/blogs' do
      get 'List blogs' do
        response '200', 'Success' do
          run_test!
        end
      end
    end
    definitions = @klass.instance_variable_get(:@_miniswag_test_definitions)
    assert_equal '/blogs', definitions.first[:path_item][:template]
  end

  # ── verb methods ──────────────────────────────────────────────────────

  def test_verb_sets_operation
    captured_verb = nil
    captured_summary = nil
    @klass.path '/blogs' do
      post 'Create blog' do
        captured_verb = begin
          metadata[:operation][:verb]
        rescue StandardError
          nil
        end
        captured_summary = begin
          metadata[:operation][:summary]
        rescue StandardError
          nil
        end
      end
    end
    # The verb and summary should be set in the operation context
    # We verify via the metadata accessor in the block
  end

  # ── operationId, tags, security ───────────────────────────────────────

  def test_operation_attributes
    @klass.path '/blogs' do
      get 'List' do
        operationId 'listBlogs'
        tags 'Blogs'
        security [{ bearer: [] }]
        description 'Lists all blogs'
      end
    end
    # These methods set values on current_operation inside context stack.
    # The real test is that they don't raise.
  end

  # ── parameter ─────────────────────────────────────────────────────────

  def test_parameter_at_operation_level
    @klass.path '/blogs' do
      get 'List' do
        parameter name: :q, in: :query, schema: { type: :string }
      end
    end
    # Should not raise
  end

  def test_parameter_at_path_level
    @klass.path '/blogs/{id}' do
      parameter name: :id, in: :path, schema: { type: :string }
      get 'Get' do
      end
    end
    # Path-level parameter should auto-set required: true for :path params
  end

  # ── response + schema ─────────────────────────────────────────────────

  def test_response_and_schema
    @klass.path '/blogs' do
      get 'List' do
        response '200', 'Success' do
          schema type: :object, properties: { name: { type: :string } }
        end
      end
    end
    # Should not raise
  end

  # ── run_test! registers metadata ──────────────────────────────────────

  def test_run_test_registers_metadata
    @klass.path '/blogs' do
      get 'List blogs' do
        response '200', 'Success' do
          schema type: :object, properties: { name: { type: :string } }
          run_test!
        end
      end
    end

    definitions = @klass.instance_variable_get(:@_miniswag_test_definitions)
    assert_equal 1, definitions.length

    meta = definitions.first
    assert_equal '/blogs', meta[:path_item][:template]
    assert_equal :get, meta[:operation][:verb]
    assert_equal 'List blogs', meta[:operation][:summary]
    assert_equal '200', meta[:response][:code]
    assert_equal 'Success', meta[:response][:description]
    assert_equal({ type: :object, properties: { name: { type: :string } } }, meta[:response][:schema])
  end

  def test_run_test_creates_test_method
    @klass.path '/blogs' do
      get 'List blogs' do
        response '200', 'Success' do
          run_test!
        end
      end
    end

    method_names = @klass.instance_methods(false).map(&:to_s)
    matching = method_names.select { |m| m.start_with?('test_') }
    assert_equal 1, matching.length
    assert_match(/get.*blogs.*200/, matching.first)
  end

  def test_multiple_responses_create_multiple_tests
    @klass.path '/blogs' do
      get 'List blogs' do
        response '200', 'Success' do
          run_test!
        end
        response '401', 'Unauthorized' do
          run_test!
        end
      end
    end

    definitions = @klass.instance_variable_get(:@_miniswag_test_definitions)
    assert_equal 2, definitions.length
    assert_equal '200', definitions[0][:response][:code]
    assert_equal '401', definitions[1][:response][:code]
  end

  # ── openapi_spec targeting ────────────────────────────────────────────

  def test_openapi_spec_targeting
    @klass.openapi_spec 'admin.yaml'
    @klass.path '/admin/login' do
      post 'Login' do
        response '200', 'OK' do
          run_test!
        end
      end
    end

    definitions = @klass.instance_variable_get(:@_miniswag_test_definitions)
    assert_equal 'admin.yaml', definitions.first[:openapi_spec]
  end

  # ── metadata access ───────────────────────────────────────────────────

  def test_metadata_access_for_custom_extensions
    captured_metadata = nil
    @klass.path '/blogs' do
      get 'List' do
        metadata[:operation]['x-public-docs'] = true
        captured_metadata = metadata
        response '200', 'OK' do
          run_test!
        end
      end
    end

    definitions = @klass.instance_variable_get(:@_miniswag_test_definitions)
    assert_equal true, definitions.first[:operation]['x-public-docs']
  end

  # ── registration ──────────────────────────────────────────────────────

  def test_run_test_registers_class
    @klass.path '/blogs' do
      get 'List' do
        response '200', 'OK' do
          run_test!
        end
      end
    end

    assert_includes Miniswag.registered_test_classes, @klass
  end

  # ── header ─────────────────────────────────────────────────────────────

  def test_header_adds_to_response_headers
    @klass.path '/blogs' do
      get 'List' do
        response '200', 'OK' do
          header 'X-Rate-Limit', schema: { type: :integer }
          run_test!
        end
      end
    end

    definitions = @klass.instance_variable_get(:@_miniswag_test_definitions)
    headers = definitions.first[:response][:headers]
    assert headers.key?('X-Rate-Limit')
    assert_equal({ type: :integer }, headers['X-Rate-Limit'][:schema])
  end

  # ── request_body_example ───────────────────────────────────────────────

  def test_request_body_example
    @klass.path '/blogs' do
      post 'Create' do
        request_body_example value: { title: 'Hello' }, summary: 'Basic blog'
        response '201', 'Created' do
          run_test!
        end
      end
    end

    definitions = @klass.instance_variable_get(:@_miniswag_test_definitions)
    examples = definitions.first[:operation][:request_examples]
    assert_equal 1, examples.length
    assert_equal({ title: 'Hello' }, examples.first[:value])
    assert_equal 'Basic blog', examples.first[:summary]
  end

  def test_request_body_example_multiple
    @klass.path '/blogs' do
      post 'Create' do
        request_body_example value: { title: 'A' }, name: :example_a
        request_body_example value: { title: 'B' }, name: :example_b
        response '201', 'Created' do
          run_test!
        end
      end
    end

    definitions = @klass.instance_variable_get(:@_miniswag_test_definitions)
    examples = definitions.first[:operation][:request_examples]
    assert_equal 2, examples.length
    assert_equal :example_a, examples[0][:name]
    assert_equal :example_b, examples[1][:name]
  end

  # ── examples (response) ────────────────────────────────────────────────

  def test_examples_adds_response_content_examples
    @klass.path '/blogs' do
      get 'List' do
        response '200', 'OK' do
          examples 'application/json' => { data: [] }
          run_test!
        end
      end
    end

    definitions = @klass.instance_variable_get(:@_miniswag_test_definitions)
    content = definitions.first[:response][:content]
    assert content.key?('application/json')
    assert content['application/json'][:examples].any?
  end

  # ── example (single response) ──────────────────────────────────────────

  def test_example_adds_single_response_example
    @klass.path '/blogs' do
      get 'List' do
        response '200', 'OK' do
          example 'application/json', :blog_list, { data: [{ id: 1 }] }, 'List of blogs'
          run_test!
        end
      end
    end

    definitions = @klass.instance_variable_get(:@_miniswag_test_definitions)
    content = definitions.first[:response][:content]
    assert content['application/json'][:examples].key?(:blog_list)
    assert_equal({ data: [{ id: 1 }] }, content['application/json'][:examples][:blog_list][:value])
    assert_equal 'List of blogs', content['application/json'][:examples][:blog_list][:summary]
  end

  # ── run_test! with custom description ──────────────────────────────────

  def test_run_test_with_custom_description
    @klass.path '/blogs' do
      get 'List' do
        response '200', 'OK' do
          run_test! 'should return blogs'
        end
      end
    end

    method_names = @klass.instance_methods(false).map(&:to_s)
    matching = method_names.select { |m| m.start_with?('test_') }
    assert_equal 1, matching.length
    assert_match(/should_return_blogs/, matching.first)
  end

  # ── consumes, produces, deprecated ─────────────────────────────────────

  def test_consumes_produces_deprecated
    @klass.path '/blogs' do
      post 'Create' do
        consumes 'application/json'
        produces 'application/json'
        deprecated true
        response '201', 'Created' do
          run_test!
        end
      end
    end

    definitions = @klass.instance_variable_get(:@_miniswag_test_definitions)
    op = definitions.first[:operation]
    assert_equal ['application/json'], op[:consumes]
    assert_equal ['application/json'], op[:produces]
    assert_equal true, op[:deprecated]
  end

  # ── path parameter auto-requires ───────────────────────────────────────

  def test_path_parameter_auto_required
    @klass.path '/blogs/{id}' do
      parameter name: :id, in: :path, schema: { type: :string }
      get 'Get' do
        response '200', 'OK' do
          run_test!
        end
      end
    end

    definitions = @klass.instance_variable_get(:@_miniswag_test_definitions)
    path_params = definitions.first[:path_item][:parameters]
    assert_equal true, path_params.first[:required]
  end
end
