# frozen_string_literal: true

require 'test_helper'

class RequestFactoryTest < Minitest::Test
  def setup
    @config = Miniswag::Configuration.new
    @config.openapi_specs = { 'v1.json' => openapi_spec }
    @metadata = {
      path_item: { template: '/blogs' },
      operation: { verb: :get }
    }
  end

  def openapi_spec
    { openapi: '3.0' }
  end

  def build_request(params = {}, headers = {})
    factory = Miniswag::RequestFactory.new(@metadata, params, headers, @config)
    factory.build_request
  end

  # ── Basic request ─────────────────────────────────────────────────────

  def test_builds_basic_request
    request = build_request
    assert_equal :get, request[:verb]
    assert_equal '/blogs', request[:path]
  end

  # ── Path parameters ───────────────────────────────────────────────────

  def test_path_parameters
    @metadata[:path_item][:template] = '/blogs/{blog_id}/comments/{id}'
    @metadata[:operation][:parameters] = [
      { name: 'blog_id', in: :path, type: :number },
      { name: 'id', in: :path, type: :number }
    ]
    request = build_request('blog_id' => 1, 'id' => 2)
    assert_equal '/blogs/1/comments/2', request[:path]
  end

  def test_path_parameters_missing_raises
    @metadata[:path_item][:template] = '/blogs/{blog_id}'
    @metadata[:operation][:parameters] = [
      { name: 'blog_id', in: :path, type: :number }
    ]
    assert_raises(ArgumentError) { build_request }
  end

  # ── Query parameters ──────────────────────────────────────────────────

  def test_query_parameters
    @metadata[:operation][:parameters] = [
      { name: 'q1', in: :query, schema: { type: :string } },
      { name: 'q2', in: :query, schema: { type: :string } }
    ]
    request = build_request('q1' => 'foo', 'q2' => 'bar')
    assert_equal '/blogs?q1=foo&q2=bar', request[:path]
  end

  def test_query_parameters_boolean_false
    @metadata[:operation][:parameters] = [
      { name: 'active', in: :query, schema: { type: :boolean } }
    ]
    request = build_request('active' => false)
    assert_equal '/blogs?active=false', request[:path]
  end

  def test_query_parameters_deep_object
    @metadata[:operation][:parameters] = [
      { name: 'things', in: :query, style: :deepObject, explode: true,
        schema: { type: :object, additionalProperties: { type: :string } } }
    ]
    request = build_request('things' => { 'foo' => 'bar' })
    assert_equal '/blogs?things%5Bfoo%5D=bar', request[:path]
  end

  def test_query_parameters_array_exploded
    @metadata[:operation][:parameters] = [
      { name: 'id', in: :query, style: :form, explode: true,
        schema: { type: :array, items: { type: :integer } } }
    ]
    request = build_request('id' => [3, 4, 5])
    assert_equal '/blogs?id=3&id=4&id=5', request[:path]
  end

  def test_query_parameters_array_unexploded
    @metadata[:operation][:parameters] = [
      { name: 'id', in: :query, style: :form, explode: false,
        schema: { type: :array, items: { type: :integer } } }
    ]
    request = build_request('id' => [3, 4, 5])
    assert_equal '/blogs?id=3,4,5', request[:path]
  end

  def test_query_parameters_pipe_delimited
    @metadata[:operation][:parameters] = [
      { name: 'id', in: :query, style: :pipeDelimited, explode: false,
        schema: { type: :array, items: { type: :integer } } }
    ]
    request = build_request('id' => [3, 4, 5])
    assert_equal '/blogs?id=3|4|5', request[:path]
  end

  def test_query_parameters_space_delimited
    @metadata[:operation][:parameters] = [
      { name: 'id', in: :query, style: :spaceDelimited, explode: false,
        schema: { type: :array, items: { type: :integer } } }
    ]
    request = build_request('id' => [3, 4, 5])
    assert_equal '/blogs?id=3%204%205', request[:path]
  end

  # ── Header parameters ─────────────────────────────────────────────────

  def test_header_parameters
    @metadata[:operation][:parameters] = [
      { name: 'Api-Key', in: :header, schema: { type: :string } }
    ]
    request = build_request({}, 'Api-Key' => 'foobar')
    assert_equal({ 'Api-Key' => 'foobar' }, request[:headers])
  end

  # ── Optional parameters not provided ──────────────────────────────────

  def test_optional_parameters_excluded
    @metadata[:operation][:parameters] = [
      { name: 'q1', in: :query, schema: { type: :string }, required: false }
    ]
    request = build_request
    assert_equal '/blogs', request[:path]
  end

  # ── Consumes/Produces ─────────────────────────────────────────────────

  def test_consumes_sets_content_type
    @metadata[:operation][:consumes] = ['application/json', 'application/xml']
    request = build_request
    assert_equal 'application/json', request[:headers]['CONTENT_TYPE']
  end

  def test_produces_sets_accept
    @metadata[:operation][:produces] = ['application/json']
    request = build_request
    assert_equal 'application/json', request[:headers]['HTTP_ACCEPT']
  end

  # ── JSON payload ──────────────────────────────────────────────────────

  def test_json_payload
    @metadata[:operation][:consumes] = ['application/json']
    @metadata[:operation][:parameters] = [
      { name: 'comment', in: :body, schema: { type: 'object' } }
    ]
    request = build_request('comment' => { text: 'hello' })
    assert_equal '{"text":"hello"}', request[:payload]
  end

  def test_missing_body_parameter_raises
    @metadata[:operation][:consumes] = ['application/json']
    @metadata[:operation][:parameters] = [
      { name: 'comment', in: :body, schema: { type: 'object' } }
    ]
    assert_raises(Miniswag::MissingParameterError) { build_request }
  end

  # ── Form payload ──────────────────────────────────────────────────────

  def test_form_payload
    @metadata[:operation][:consumes] = ['multipart/form-data']
    @metadata[:operation][:parameters] = [
      { name: 'f1', in: :formData, schema: { type: :string } },
      { name: 'f2', in: :formData, schema: { type: :string } }
    ]
    request = build_request('f1' => 'foo', 'f2' => 'bar')
    assert_equal({ 'f1' => 'foo', 'f2' => 'bar' }, request[:payload])
  end

  # ── Security ──────────────────────────────────────────────────────────

  def test_bearer_auth
    spec = openapi_spec.merge(
      components: { securitySchemes: { bearer: { type: :http, scheme: :bearer } } }
    )
    @config.openapi_specs = { 'v1.json' => spec }
    @metadata[:operation][:security] = [{ bearer: [] }]
    request = build_request({}, 'Authorization' => 'Bearer token123')
    assert_equal 'Bearer token123', request[:headers]['HTTP_AUTHORIZATION']
  end

  def test_api_key_in_query
    spec = openapi_spec.merge(
      components: { securitySchemes: { api_key: { type: :apiKey, name: 'api_key', in: :query } } }
    )
    @config.openapi_specs = { 'v1.json' => spec }
    @metadata[:operation][:security] = [{ api_key: [] }]
    request = build_request('api_key' => 'foobar')
    assert_equal '/blogs?api_key=foobar', request[:path]
  end

  def test_api_key_in_header
    spec = openapi_spec.merge(
      components: { securitySchemes: { api_key: { type: :apiKey, name: 'api_key', in: :header } } }
    )
    @config.openapi_specs = { 'v1.json' => spec }
    @metadata[:operation][:security] = [{ api_key: [] }]
    request = build_request({}, 'api_key' => 'foobar')
    assert_equal 'foobar', request[:headers]['api_key']
  end

  # ── Referenced parameters ─────────────────────────────────────────────

  def test_referenced_parameters
    spec = openapi_spec.merge(
      openapi: '3.0.1',
      components: { parameters: { q1: { name: 'q1', in: :query, schema: { type: :string } } } }
    )
    @config.openapi_specs = { 'v1.json' => spec }
    @metadata[:operation][:parameters] = [{ '$ref' => '#/components/parameters/q1' }]
    request = build_request('q1' => 'foo')
    assert_equal '/blogs?q1=foo', request[:path]
  end

  # ── Path-level parameters ─────────────────────────────────────────────

  def test_path_level_parameters
    @metadata[:operation][:parameters] = [{ name: 'q1', in: :query, schema: { type: :string } }]
    @metadata[:path_item][:parameters] = [{ name: 'q2', in: :query, schema: { type: :string } }]
    request = build_request('q1' => 'foo', 'q2' => 'bar')
    assert_equal '/blogs?q1=foo&q2=bar', request[:path]
  end

  # ── Server base path ──────────────────────────────────────────────────

  def test_server_base_path
    spec = openapi_spec.merge(
      servers: [{
        url: '{protocol}://{defaultHost}',
        variables: {
          protocol: { default: :https },
          defaultHost: { default: 'www.example.com' }
        }
      }]
    )
    @config.openapi_specs = { 'v1.json' => spec }
    request = build_request
    assert_equal '/blogs', request[:path]
  end

  # ── Global security ───────────────────────────────────────────────────

  def test_global_security
    spec = openapi_spec.merge(
      components: { securitySchemes: { api_key: { type: :apiKey, name: 'api_key', in: :query } } },
      security: [{ api_key: [] }]
    )
    @config.openapi_specs = { 'v1.json' => spec }
    request = build_request('api_key' => 'foobar')
    assert_equal '/blogs?api_key=foobar', request[:path]
  end

  # ── Query object form explode=false ────────────────────────────────────

  def test_query_object_form_unexploded
    @metadata[:operation][:parameters] = [
      { name: 'things', in: :query, style: :form, explode: false,
        schema: { type: :object, additionalProperties: { type: :string } } }
    ]
    request = build_request('things' => { 'foo' => 'bar' })
    assert_equal '/blogs?things=foo,bar', request[:path]
  end

  def test_query_object_form_exploded
    @metadata[:operation][:parameters] = [
      { name: 'things', in: :query, style: :form, explode: true,
        schema: { type: :object, additionalProperties: { type: :string } } }
    ]
    request = build_request('things' => { 'foo' => 'bar' })
    assert_equal '/blogs?foo=bar', request[:path]
  end

  def test_query_deep_object_nested
    @metadata[:operation][:parameters] = [
      { name: 'things', in: :query, style: :deepObject, explode: true,
        schema: { type: :object } }
    ]
    request = build_request('things' => { 'foo' => { 'bar' => 'baz' } })
    assert_equal '/blogs?things%5Bfoo%5D%5Bbar%5D=baz', request[:path]
  end

  # ── Query array exploded variants ──────────────────────────────────────

  def test_query_array_space_delimited_exploded
    @metadata[:operation][:parameters] = [
      { name: 'id', in: :query, style: :spaceDelimited, explode: true,
        schema: { type: :array, items: { type: :integer } } }
    ]
    request = build_request('id' => [3, 4, 5])
    assert_equal '/blogs?id=3&id=4&id=5', request[:path]
  end

  def test_query_array_pipe_delimited_exploded
    @metadata[:operation][:parameters] = [
      { name: 'id', in: :query, style: :pipeDelimited, explode: true,
        schema: { type: :array, items: { type: :integer } } }
    ]
    request = build_request('id' => [3, 4, 5])
    assert_equal '/blogs?id=3&id=4&id=5', request[:path]
  end

  # ── Query with $ref schema ─────────────────────────────────────────────

  def test_query_with_ref_schema
    @metadata[:operation][:parameters] = [
      { name: 'things', in: :query,
        schema: { '$ref' => '#/components/schemas/FooType' } }
    ]
    request = build_request('things' => 'foo')
    assert_equal '/blogs?things=foo', request[:path]
  end

  # ── Explicit Content-Type override ─────────────────────────────────────

  def test_explicit_content_type_override
    @metadata[:operation][:consumes] = ['application/json', 'application/xml']
    request = build_request({}, 'Content-Type' => 'application/xml')
    assert_equal 'application/xml', request[:headers]['CONTENT_TYPE']
  end

  # ── Explicit Accept override ───────────────────────────────────────────

  def test_explicit_accept_override
    @metadata[:operation][:produces] = ['application/json', 'application/xml']
    request = build_request({}, 'Accept' => 'application/xml')
    assert_equal 'application/xml', request[:headers]['HTTP_ACCEPT']
  end

  # ── Plain text payload ─────────────────────────────────────────────────

  def test_plain_text_payload
    @metadata[:operation][:consumes] = ['text/plain']
    @metadata[:operation][:parameters] = [
      { name: 'comment', in: :body, schema: { type: 'string' } }
    ]
    request = build_request('comment' => 'plain text comment')
    assert_equal 'plain text comment', request[:payload]
  end

  # ── Host header ────────────────────────────────────────────────────────

  def test_host_header_explicit
    @metadata[:operation][:host] = 'swagger.io'
    request = build_request
    assert_equal 'swagger.io', request[:headers]['HTTP_HOST']
  end

  def test_host_header_nil
    @metadata[:operation][:host] = nil
    request = build_request
    refute request[:headers].key?('HTTP_HOST')
  end

  # ── Basic auth ─────────────────────────────────────────────────────────

  def test_basic_auth
    spec = openapi_spec.merge(
      openapi: '3.0.1',
      components: { securitySchemes: { basic: { type: :basic } } }
    )
    @config.openapi_specs = { 'v1.json' => spec }
    @metadata[:operation][:security] = [{ basic: [] }]
    request = build_request({}, 'Authorization' => 'Basic foobar')
    assert_equal 'Basic foobar', request[:headers]['HTTP_AUTHORIZATION']
  end

  # ── OAuth2 ─────────────────────────────────────────────────────────────

  def test_oauth2
    spec = openapi_spec.merge(
      components: { securitySchemes: { oauth2: { type: :oauth2, flows: { implicit: { scopes: ['read:blogs'] } } } } }
    )
    @config.openapi_specs = { 'v1.json' => spec }
    @metadata[:operation][:security] = [{ oauth2: ['read:blogs'] }]
    request = build_request({}, 'Authorization' => 'Bearer foobar')
    assert_equal 'Bearer foobar', request[:headers]['HTTP_AUTHORIZATION']
  end

  # ── Paired security ────────────────────────────────────────────────────

  def test_paired_security
    spec = openapi_spec.merge(
      components: {
        securitySchemes: {
          basic: { type: :http, scheme: :basic },
          api_key: { type: :apiKey, name: 'api_key', in: :query }
        }
      }
    )
    @config.openapi_specs = { 'v1.json' => spec }
    @metadata[:operation][:security] = [{ basic: [], api_key: [] }]
    request = build_request({ 'api_key' => 'foobar' }, { 'Authorization' => 'Basic foobar' })
    assert_equal 'Basic foobar', request[:headers]['HTTP_AUTHORIZATION']
    assert_equal '/blogs?api_key=foobar', request[:path]
  end

  # ── Global consumes ────────────────────────────────────────────────────

  def test_global_consumes
    spec = openapi_spec.merge(consumes: ['application/xml'])
    @config.openapi_specs = { 'v1.json' => spec }
    request = build_request
    assert_equal 'application/xml', request[:headers]['CONTENT_TYPE']
  end

  # ── apiKey deduplication ───────────────────────────────────────────────

  def test_api_key_not_duplicated_when_already_in_params
    spec = openapi_spec.merge(
      components: { securitySchemes: { api_key: { type: :apiKey, name: 'api_key', in: :header } } }
    )
    @config.openapi_specs = { 'v1.json' => spec }
    @metadata[:operation][:security] = [{ api_key: [] }]
    @metadata[:operation][:parameters] = [
      { name: 'q1', in: :query, schema: { type: :string } },
      { name: 'api_key', in: :header, schema: { type: :string } }
    ]
    request = build_request({ 'q1' => 'foo' }, { 'api_key' => 'foobar' })
    assert_equal 'foobar', request[:headers]['api_key']
    # Should only appear once in params list
    assert_equal 2, @metadata[:operation][:parameters].size
  end

  # ── Datetime query parameter ───────────────────────────────────────────

  def test_query_datetime_parameter
    date_time = '2001-02-03T04:05:06-07:00'
    @metadata[:operation][:parameters] = [
      { name: 'date_time', in: :query, schema: { type: :string, format: :datetime } }
    ]
    request = build_request('date_time' => date_time)
    assert_equal '/blogs?date_time=2001-02-03T04%3A05%3A06-07%3A00', request[:path]
  end
end
