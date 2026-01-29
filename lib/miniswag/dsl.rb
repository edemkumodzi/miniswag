# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/hash/deep_merge'

module Miniswag
  # Class-level DSL methods that mirror rswag's ExampleGroupHelpers.
  #
  # The DSL builds a tree of metadata on the test class. Each `path` block
  # creates a path context, each verb block creates an operation context,
  # and each `response` block creates a response context. `run_test!`
  # generates a Minitest test method from the accumulated metadata.
  #
  # Metadata is stored in class instance variables and accumulated via
  # a context stack so nested blocks see their parent metadata.
  module DSL
    def self.extended(base)
      base.instance_variable_set(:@_miniswag_context_stack, [])
      base.instance_variable_set(:@_miniswag_test_definitions, [])
      base.instance_variable_set(:@_miniswag_openapi_spec_name, nil)
    end

    # Set which openapi spec file this test class targets (e.g. "admin.yaml")
    def openapi_spec(name)
      @_miniswag_openapi_spec_name = name
    end

    # ── Path block ──────────────────────────────────────────────────────

    def path(template, &block)
      ctx = { path_item: { template: template, parameters: [] }, scope: :path }
      push_context(ctx, &block)
    end

    # ── HTTP verb blocks ────────────────────────────────────────────────

    %i[get post patch put delete head options trace].each do |verb|
      define_method(verb) do |summary, &block|
        ctx = {
          operation: {
            verb: verb,
            summary: summary,
            parameters: []
          },
          scope: :operation
        }
        push_context(ctx, &block)
      end
    end

    # ── Operation-level attributes ──────────────────────────────────────

    %i[operationId deprecated security].each do |attr_name|
      define_method(attr_name) do |value|
        current_operation[attr_name] = value
      end
    end

    def description(value)
      current_operation[:description] = value
    end

    %i[tags consumes produces schemes].each do |attr_name|
      define_method(attr_name) do |*value|
        current_operation[attr_name] = value
      end
    end

    # ── Parameters ──────────────────────────────────────────────────────

    def parameter(attributes)
      attributes[:required] = true if attributes[:in] && attributes[:in].to_sym == :path
      scope = current_scope
      if scope == :operation
        current_operation[:parameters] ||= []
        current_operation[:parameters] << attributes
      else
        current_path_item[:parameters] ||= []
        current_path_item[:parameters] << attributes
      end
    end

    def request_body_example(value:, summary: nil, name: nil)
      return unless current_scope == :operation

      current_operation[:request_examples] ||= []
      example_entry = { value: value }
      example_entry[:summary] = summary if summary
      example_entry[:name] = name || current_operation[:request_examples].length
      current_operation[:request_examples] << example_entry
    end

    # ── Response block ──────────────────────────────────────────────────

    def response(code, description, **options, &block)
      ctx = {
        response: { code: code, description: description }.merge(options),
        scope: :response,
        before_blocks: [],
        params_block: nil,
        after_test_block: nil
      }
      push_context(ctx, &block)
    end

    # ── Response-level attributes ───────────────────────────────────────

    def schema(value)
      current_response[:schema] = value
    end

    def header(name, attributes)
      current_response[:headers] ||= {}
      current_response[:headers][name] = attributes
    end

    def examples(examples_hash = nil)
      return if examples_hash.nil?

      examples_hash.each_with_index do |(mime, example_object), index|
        example(mime, "example_#{index}", example_object)
      end
    end

    def example(mime, name, value, summary = nil, description = nil)
      current_response[:content] = {} if current_response[:content].blank?
      if current_response[:content][mime].blank?
        current_response[:content][mime] = {}
        current_response[:content][mime][:examples] = {}
      end
      example_object = { value: value, summary: summary, description: description }.compact
      current_response[:content][mime][:examples].merge!(name.to_sym => example_object)
    end

    # ── Metadata access (for direct manipulation like metadata[:operation]["x-public-docs"]) ─

    def metadata
      @_miniswag_context_stack.last || {}
    end

    # ── Setup blocks within response context ────────────────────────────

    # Register a block to run before the test request (within response context).
    # Replaces RSpec's `let!` blocks for test data setup.
    def before(&block)
      ctx = @_miniswag_context_stack.last
      ctx[:before_blocks] << block if ctx && ctx.key?(:before_blocks)
    end

    # Register a block that returns a hash of parameter values.
    # Keys should match parameter names (including Authorization, path params, etc.)
    def params(&block)
      ctx = @_miniswag_context_stack.last
      ctx[:params_block] = block if ctx
    end

    # ── Test generation ─────────────────────────────────────────────────

    def run_test!(test_description = nil, &after_block)
      # Snapshot all the accumulated metadata at this point
      path_item = deep_dup(current_path_item)
      operation = deep_dup(current_operation)
      response_meta = deep_dup(current_response)
      openapi_spec_name = @_miniswag_openapi_spec_name
      before_blocks = (@_miniswag_context_stack.last[:before_blocks] || []).dup
      params_block = @_miniswag_context_stack.last[:params_block]

      test_description ||= "returns a #{response_meta[:code]} response"

      # Build a unique test name from path + verb + response code + description
      verb = operation[:verb]
      path_template = path_item[:template]
      test_name = "test_#{verb}_#{path_template}_#{response_meta[:code]}_#{test_description}"
                  .gsub(/[^a-zA-Z0-9_]/, '_')
                  .gsub(/_+/, '_')
                  .downcase

      # Build full metadata hash (mirrors rswag's metadata structure)
      full_metadata = {
        path_item: path_item,
        operation: operation,
        response: response_meta,
        openapi_spec: openapi_spec_name
      }

      # Register for OpenAPI generation
      @_miniswag_test_definitions ||= []
      @_miniswag_test_definitions << full_metadata

      # Register this class with the global registry for OpenAPI generation
      Miniswag.register_test_class(self)

      # Define the actual Minitest test method
      user_block = after_block
      captured_before_blocks = before_blocks
      captured_params_block = params_block
      captured_metadata = full_metadata

      define_method(test_name) do
        # Run before blocks in instance context
        captured_before_blocks.each { |blk| instance_exec(&blk) }

        # Collect params from the params block
        test_params = captured_params_block ? instance_exec(&captured_params_block) : {}
        test_params ||= {}

        # Merge instance variable @_miniswag_params if set (from setup blocks)
        if defined?(@_miniswag_params) && @_miniswag_params.is_a?(Hash)
          test_params = @_miniswag_params.merge(test_params)
        end

        # Build and send request
        factory = Miniswag::RequestFactory.new(captured_metadata, test_params)
        request = factory.build_request

        send(
          request[:verb],
          request[:path],
          params: request[:payload],
          headers: request[:headers]
        )

        # Validate response
        validator = Miniswag::ResponseValidator.new
        validator.validate!(captured_metadata, response)

        # Register a Minitest assertion so tests are not flagged as "missing assertions"
        expected_code = captured_metadata[:response][:code].to_s
        assert_equal expected_code, response.code,
                     "Expected response code #{expected_code} but got #{response.code}"

        # Run user's additional assertions
        instance_exec(response, &user_block) if user_block
      end
    end

    private

    def push_context(ctx, &block)
      @_miniswag_context_stack.push(ctx)
      instance_exec(&block) if block
      @_miniswag_context_stack.pop
    end

    def current_path_item
      frame = @_miniswag_context_stack.find { |c| c[:scope] == :path }
      frame ? frame[:path_item] : {}
    end

    def current_operation
      frame = @_miniswag_context_stack.reverse.find { |c| c[:scope] == :operation }
      frame ? frame[:operation] : {}
    end

    def current_response
      frame = @_miniswag_context_stack.reverse.find { |c| c[:scope] == :response }
      frame ? frame[:response] : {}
    end

    def current_scope
      frame = @_miniswag_context_stack.last
      frame ? frame[:scope] : nil
    end

    def deep_dup(obj)
      case obj
      when Hash
        obj.each_with_object({}) { |(k, v), h| h[k] = deep_dup(v) }
      when Array
        obj.map { |v| deep_dup(v) }
      else
        begin
          obj.dup
        rescue TypeError
          obj
        end
      end
    end
  end
end
