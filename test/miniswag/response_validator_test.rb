# frozen_string_literal: true

require 'test_helper'

# Minimal response struct for testing
MockResponse = Struct.new(:code, :headers, :body, keyword_init: true)

class ResponseValidatorTest < Minitest::Test
  def setup
    @config = Miniswag::Configuration.new
    @config.openapi_specs = { 'v1.json' => {} }
    @validator = Miniswag::ResponseValidator.new(@config)
    @schema = {
      type: :object,
      properties: {
        text: { type: :string },
        number: { type: :integer }
      },
      required: %w[text number]
    }
    @metadata = {
      response: {
        code: 200,
        headers: {
          'X-Rate-Limit' => { type: :integer },
          'X-Optional' => { schema: { type: :string }, required: false },
          'X-Nullable' => { schema: { type: :string, nullable: true } }
        },
        schema: @schema
      }
    }
  end

  def valid_response
    MockResponse.new(
      code: '200',
      headers: { 'X-Rate-Limit' => '10', 'X-Optional' => 'yes', 'X-Nullable' => 'val' },
      body: '{"text":"hello","number":3}'
    )
  end

  # ── Matching response ─────────────────────────────────────────────────

  def test_valid_response_passes
    @validator.validate!(@metadata, valid_response)
  end

  # ── Status code ───────────────────────────────────────────────────────

  def test_wrong_status_code_raises
    response = valid_response
    response.code = '400'
    assert_raises(Miniswag::UnexpectedResponse) { @validator.validate!(@metadata, response) }
  end

  # ── Headers ───────────────────────────────────────────────────────────

  def test_missing_required_header_raises
    response = valid_response
    response.headers = {}
    assert_raises(Miniswag::UnexpectedResponse) { @validator.validate!(@metadata, response) }
  end

  def test_missing_optional_header_passes
    response = valid_response
    response.headers = { 'X-Rate-Limit' => '10', 'X-Nullable' => 'val' }
    @validator.validate!(@metadata, response)
  end

  def test_nullable_header_with_nil_value_passes
    response = valid_response
    response.headers = { 'X-Rate-Limit' => '10', 'X-Nullable' => nil }
    @validator.validate!(@metadata, response)
  end

  def test_missing_nullable_header_raises
    response = valid_response
    response.headers = { 'X-Rate-Limit' => '10' }
    assert_raises(Miniswag::UnexpectedResponse) { @validator.validate!(@metadata, response) }
  end

  # ── Body schema ───────────────────────────────────────────────────────

  def test_body_mismatch_raises
    response = valid_response
    response.body = '{"foo":"bar"}'
    assert_raises(Miniswag::UnexpectedResponse) { @validator.validate!(@metadata, response) }
  end

  def test_no_schema_skips_body_validation
    @metadata[:response].delete(:schema)
    response = valid_response
    response.body = 'anything'
    @validator.validate!(@metadata, response)
  end

  # ── Additional properties ─────────────────────────────────────────────

  def test_additional_properties_pass_by_default
    response = valid_response
    response.body = '{"text":"hello","number":3,"extra":"val"}'
    @validator.validate!(@metadata, response)
  end

  def test_additional_properties_fail_when_strict
    @config.openapi_no_additional_properties = true
    response = valid_response
    response.body = '{"text":"hello","number":3,"extra":"val"}'
    assert_raises(Miniswag::UnexpectedResponse) { @validator.validate!(@metadata, response) }
  end

  def test_additional_properties_metadata_override
    @config.openapi_no_additional_properties = false
    @metadata[:openapi_no_additional_properties] = true
    response = valid_response
    response.body = '{"text":"hello","number":3,"extra":"val"}'
    assert_raises(Miniswag::UnexpectedResponse) { @validator.validate!(@metadata, response) }
  end

  # ── Missing properties ────────────────────────────────────────────────

  def test_missing_required_property_raises
    response = valid_response
    response.body = '{"number":3}'
    assert_raises(Miniswag::UnexpectedResponse) { @validator.validate!(@metadata, response) }
  end

  # ── Referenced schemas ────────────────────────────────────────────────

  def test_referenced_schema_validation
    @config.openapi_specs = {
      'v1.json' => {
        components: {
          schemas: {
            'blog' => {
              type: :object,
              properties: { foo: { type: :string } },
              required: ['foo']
            }
          }
        }
      }
    }
    @metadata[:response][:schema] = { '$ref' => '#/components/schemas/blog' }
    response = valid_response
    response.body = '{"text":"hello","number":3}'
    assert_raises(Miniswag::UnexpectedResponse) { @validator.validate!(@metadata, response) }
  end

  # ── Nullable schemas ──────────────────────────────────────────────────

  def test_nullable_ref_with_nullable_attribute
    @config.openapi_specs = { 'v1.json' => { components: { schemas: {} } } }
    @metadata[:response][:schema] = {
      properties: { blog: { '$ref' => '#/components/schema/blog', 'nullable' => true } },
      required: ['blog']
    }
    response = valid_response
    response.body = '{"blog":null}'
    @validator.validate!(@metadata, response)
  end

  def test_nullable_ref_with_x_nullable_attribute
    @config.openapi_specs = { 'v1.json' => { components: { schemas: {} } } }
    @metadata[:response][:schema] = {
      properties: { blog: { '$ref' => '#/components/schema/blog', 'x-nullable' => true } },
      required: ['blog']
    }
    response = valid_response
    response.body = '{"blog":null}'
    @validator.validate!(@metadata, response)
  end

  # ── Nullable oneOf with $ref ───────────────────────────────────────────

  def test_nullable_one_of_with_nullable
    @config.openapi_specs = { 'v1.json' => { components: { schemas: {} } } }
    @metadata[:response][:schema] = {
      properties: { blog: { oneOf: [{ '$ref' => '#/components/schema/blog' }], 'nullable' => true } },
      required: ['blog']
    }
    response = valid_response
    response.body = '{"blog":null}'
    @validator.validate!(@metadata, response)
  end

  def test_nullable_one_of_with_x_nullable
    @config.openapi_specs = { 'v1.json' => { components: { schemas: {} } } }
    @metadata[:response][:schema] = {
      properties: { blog: { oneOf: [{ '$ref' => '#/components/schema/blog' }], 'x-nullable' => true } },
      required: ['blog']
    }
    response = valid_response
    response.body = '{"blog":null}'
    @validator.validate!(@metadata, response)
  end

  # ── all_properties_required permutations ───────────────────────────────

  def test_all_properties_required_config_enabled_missing_property_raises
    @config.openapi_all_properties_required = true
    response = valid_response
    response.body = '{"number":3}'
    assert_raises(Miniswag::UnexpectedResponse) { @validator.validate!(@metadata, response) }
  end

  def test_all_properties_required_metadata_override_enabled
    @config.openapi_all_properties_required = false
    @metadata[:openapi_all_properties_required] = true
    response = valid_response
    response.body = '{"number":3}'
    assert_raises(Miniswag::UnexpectedResponse) { @validator.validate!(@metadata, response) }
  end

  def test_all_properties_required_metadata_override_disabled
    @config.openapi_all_properties_required = true
    @metadata[:openapi_all_properties_required] = false
    response = valid_response
    # Body has both required properties, should pass regardless
    @validator.validate!(@metadata, response)
  end

  # ── no_additional_properties config enabled, metadata disabled ─────────

  def test_no_additional_properties_config_enabled_metadata_disabled
    @config.openapi_no_additional_properties = true
    @metadata[:openapi_no_additional_properties] = false
    response = valid_response
    response.body = '{"text":"hello","number":3,"extra":"val"}'
    # metadata override disables it
    @validator.validate!(@metadata, response)
  end

  # ── Missing + additional properties ────────────────────────────────────

  def test_missing_and_additional_properties_raises
    response = valid_response
    response.body = '{"foo":"bar","text":"hello"}'
    assert_raises(Miniswag::UnexpectedResponse) { @validator.validate!(@metadata, response) }
  end

  def test_missing_and_additional_no_required_in_schema_passes_by_default
    @metadata[:response][:schema] = {
      type: :object,
      properties: { text: { type: :string }, number: { type: :integer } }
    }
    response = valid_response
    response.body = '{"foo":"bar","text":"hello"}'
    @validator.validate!(@metadata, response)
  end

  def test_missing_and_additional_no_required_with_all_required_raises
    @config.openapi_all_properties_required = true
    @metadata[:response][:schema] = {
      type: :object,
      properties: { text: { type: :string }, number: { type: :integer } }
    }
    response = valid_response
    response.body = '{"foo":"bar","text":"hello"}'
    assert_raises(Miniswag::UnexpectedResponse) { @validator.validate!(@metadata, response) }
  end

  def test_missing_and_additional_no_required_with_no_additional_raises
    @config.openapi_no_additional_properties = true
    @metadata[:response][:schema] = {
      type: :object,
      properties: { text: { type: :string }, number: { type: :integer } }
    }
    response = valid_response
    response.body = '{"foo":"bar","text":"hello"}'
    assert_raises(Miniswag::UnexpectedResponse) { @validator.validate!(@metadata, response) }
  end

  # ── Schema without required + additional properties ────────────────────

  def test_additional_properties_no_required_in_schema_passes
    @metadata[:response][:schema] = {
      type: :object,
      properties: { text: { type: :string }, number: { type: :integer } }
    }
    response = valid_response
    response.body = '{"text":"hello","number":3,"extra":"val"}'
    @validator.validate!(@metadata, response)
  end

  def test_additional_properties_no_required_with_strict_raises
    @config.openapi_no_additional_properties = true
    @metadata[:response][:schema] = {
      type: :object,
      properties: { text: { type: :string }, number: { type: :integer } }
    }
    response = valid_response
    response.body = '{"text":"hello","number":3,"extra":"val"}'
    assert_raises(Miniswag::UnexpectedResponse) { @validator.validate!(@metadata, response) }
  end
end
