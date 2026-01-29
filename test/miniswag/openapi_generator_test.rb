# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'json'
require 'yaml'

class OpenapiGeneratorTest < Minitest::Test
  def setup
    Miniswag.reset!
    @tmpdir = Dir.mktmpdir('miniswag_test')
    @config = Miniswag.config
    @config.openapi_root = @tmpdir
    @config.openapi_format = :json
    @config.openapi_specs = {
      'v1/openapi.json' => {
        openapi: '3.0.1',
        info: { title: 'Test API', version: 'v1' },
        paths: {}
      }
    }
  end

  def teardown
    FileUtils.rm_rf(@tmpdir) if @tmpdir
    Miniswag.reset!
  end

  def register_test_class_with_definitions(definitions)
    klass = Class.new
    klass.instance_variable_set(:@_miniswag_test_definitions, definitions)
    klass.define_singleton_method(:miniswag_test_definitions) do
      @_miniswag_test_definitions
    end
    Miniswag.register_test_class(klass)
  end

  # ── Basic generation ──────────────────────────────────────────────────

  def test_generates_json_file
    register_test_class_with_definitions([
                                           {
                                             path_item: { template: '/blogs' },
                                             operation: { verb: :get, summary: 'List blogs', parameters: [] },
                                             response: { code: '200', description: 'Success' },
                                             openapi_spec: nil
                                           }
                                         ])

    generator = Miniswag::OpenapiGenerator.new
    generator.generate!

    file_path = File.join(@tmpdir, 'v1/openapi.json')
    assert File.exist?(file_path), "Expected #{file_path} to exist"

    doc = JSON.parse(File.read(file_path))
    assert_equal '3.0.1', doc['openapi']
    assert doc['paths'].key?('/blogs')
    assert doc['paths']['/blogs']['get']['responses'].key?('200')
  end

  # ── YAML format ───────────────────────────────────────────────────────

  def test_generates_yaml_file
    @config.openapi_format = :yaml
    register_test_class_with_definitions([
                                           {
                                             path_item: { template: '/blogs' },
                                             operation: { verb: :get, summary: 'List blogs', parameters: [] },
                                             response: { code: '200', description: 'Success' },
                                             openapi_spec: nil
                                           }
                                         ])

    generator = Miniswag::OpenapiGenerator.new
    generator.generate!

    file_path = File.join(@tmpdir, 'v1/openapi.json')
    assert File.exist?(file_path)

    # Should be valid YAML but not valid JSON
    assert_raises(JSON::ParserError) { JSON.parse(File.read(file_path)) }
    doc = YAML.safe_load(File.read(file_path))
    assert_equal '3.0.1', doc['openapi']
  end

  # ── Multiple responses ────────────────────────────────────────────────

  def test_merges_multiple_responses
    register_test_class_with_definitions([
                                           {
                                             path_item: { template: '/blogs' },
                                             operation: { verb: :get, summary: 'List blogs', parameters: [] },
                                             response: { code: '200', description: 'Success' },
                                             openapi_spec: nil
                                           },
                                           {
                                             path_item: { template: '/blogs' },
                                             operation: { verb: :get, summary: 'List blogs', parameters: [] },
                                             response: { code: '401', description: 'Unauthorized' },
                                             openapi_spec: nil
                                           }
                                         ])

    generator = Miniswag::OpenapiGenerator.new
    generator.generate!

    file_path = File.join(@tmpdir, 'v1/openapi.json')
    doc = JSON.parse(File.read(file_path))
    responses = doc['paths']['/blogs']['get']['responses']
    assert responses.key?('200')
    assert responses.key?('401')
  end

  # ── Produces → content conversion ─────────────────────────────────────

  def test_produces_converts_to_content
    register_test_class_with_definitions([
                                           {
                                             path_item: { template: '/blogs' },
                                             operation: { verb: :get, summary: 'List blogs',
                                                          produces: ['application/json'], parameters: [] },
                                             response: { code: '200', description: 'Success',
                                                         schema: { type: :object, properties: { name: { type: :string } } } },
                                             openapi_spec: nil
                                           }
                                         ])

    generator = Miniswag::OpenapiGenerator.new
    generator.generate!

    file_path = File.join(@tmpdir, 'v1/openapi.json')
    doc = JSON.parse(File.read(file_path))
    response = doc['paths']['/blogs']['get']['responses']['200']

    # Schema should be moved under content/application/json
    assert response.key?('content')
    assert response['content'].key?('application/json')
    assert response['content']['application/json'].key?('schema')
    # Schema should be removed from response top level
    refute response.key?('schema')
  end

  # ── document: false is skipped ────────────────────────────────────────

  def test_skips_document_false
    register_test_class_with_definitions([
                                           {
                                             path_item: { template: '/blogs' },
                                             operation: { verb: :get, summary: 'List blogs', parameters: [] },
                                             response: { code: '200', description: 'Success' },
                                             openapi_spec: nil,
                                             document: false
                                           }
                                         ])

    generator = Miniswag::OpenapiGenerator.new
    generator.generate!

    file_path = File.join(@tmpdir, 'v1/openapi.json')
    doc = JSON.parse(File.read(file_path))
    assert_equal({}, doc['paths'])
  end

  # ── formData parameter → requestBody ──────────────────────────────────

  def test_form_data_parameters_become_request_body
    register_test_class_with_definitions([
                                           {
                                             path_item: { template: '/blogs' },
                                             operation: {
                                               verb: :post,
                                               summary: 'Create blog',
                                               consumes: ['multipart/form-data'],
                                               parameters: [
                                                 { name: 'title', in: :formData, schema: { type: :string },
                                                   required: true },
                                                 { name: 'body', in: :formData, schema: { type: :string } }
                                               ]
                                             },
                                             response: { code: '201', description: 'Created' },
                                             openapi_spec: nil
                                           }
                                         ])

    generator = Miniswag::OpenapiGenerator.new
    generator.generate!

    file_path = File.join(@tmpdir, 'v1/openapi.json')
    doc = JSON.parse(File.read(file_path))
    operation = doc['paths']['/blogs']['post']

    # formData params should be removed from parameters
    remaining_params = operation['parameters'] || []
    form_params = remaining_params.select { |p| p['in'] == 'formData' }
    assert_empty form_params

    # Should have requestBody instead
    assert operation.key?('requestBody')
    assert operation['requestBody']['content'].key?('multipart/form-data')
  end

  # ── body parameter → requestBody ──────────────────────────────────────

  def test_body_parameter_becomes_request_body
    register_test_class_with_definitions([
                                           {
                                             path_item: { template: '/blogs' },
                                             operation: {
                                               verb: :post,
                                               summary: 'Create blog',
                                               consumes: ['application/json'],
                                               parameters: [
                                                 { name: 'blog', in: :body, schema: { type: :object, properties: { title: { type: :string } } },
                                                   required: true }
                                               ]
                                             },
                                             response: { code: '201', description: 'Created' },
                                             openapi_spec: nil
                                           }
                                         ])

    generator = Miniswag::OpenapiGenerator.new
    generator.generate!

    file_path = File.join(@tmpdir, 'v1/openapi.json')
    doc = JSON.parse(File.read(file_path))
    operation = doc['paths']['/blogs']['post']
    assert operation.key?('requestBody')
    assert operation['requestBody']['content'].key?('application/json')
  end

  # ── Targeted openapi_spec ─────────────────────────────────────────────

  def test_targeted_openapi_spec
    @config.openapi_specs['admin.json'] = {
      openapi: '3.0.1',
      info: { title: 'Admin API', version: 'v1' },
      paths: {}
    }

    register_test_class_with_definitions([
                                           {
                                             path_item: { template: '/admin/users' },
                                             operation: { verb: :get, summary: 'List users', parameters: [] },
                                             response: { code: '200', description: 'Success' },
                                             openapi_spec: 'admin.json'
                                           }
                                         ])

    generator = Miniswag::OpenapiGenerator.new
    generator.generate!

    # admin.json should have the path
    admin_path = File.join(@tmpdir, 'admin.json')
    admin_doc = JSON.parse(File.read(admin_path))
    assert admin_doc['paths'].key?('/admin/users')

    # v1/openapi.json should NOT have it
    v1_path = File.join(@tmpdir, 'v1/openapi.json')
    v1_doc = JSON.parse(File.read(v1_path))
    refute v1_doc['paths'].key?('/admin/users')
  end

  # ── Enum parameters ────────────────────────────────────────────────────

  def test_enum_parameters_converted
    register_test_class_with_definitions([
                                           {
                                             path_item: { template: '/blogs' },
                                             operation: {
                                               verb: :get, summary: 'List', parameters: [
                                                 { name: 'status', in: :query, schema: { type: :string }, enum: %w[draft published] }
                                               ]
                                             },
                                             response: { code: '200', description: 'OK' },
                                             openapi_spec: nil
                                           }
                                         ])

    generator = Miniswag::OpenapiGenerator.new
    generator.generate!

    file_path = File.join(@tmpdir, 'v1/openapi.json')
    doc = JSON.parse(File.read(file_path))
    param = doc['paths']['/blogs']['get']['parameters'].first
    assert_equal %w[draft published], param['schema']['enum']
    refute param.key?('enum')
  end

  # ── Enum hash generates description ────────────────────────────────────

  def test_enum_hash_generates_description
    register_test_class_with_definitions([
                                           {
                                             path_item: { template: '/blogs' },
                                             operation: {
                                               verb: :get, summary: 'List', parameters: [
                                                 { name: 'status', in: :query, schema: { type: :string },
                                                   description: 'Filter by status',
                                                   enum: { draft: 'Not published', published: 'Live' } }
                                               ]
                                             },
                                             response: { code: '200', description: 'OK' },
                                             openapi_spec: nil
                                           }
                                         ])

    generator = Miniswag::OpenapiGenerator.new
    generator.generate!

    file_path = File.join(@tmpdir, 'v1/openapi.json')
    doc = JSON.parse(File.read(file_path))
    param = doc['paths']['/blogs']['get']['parameters'].first
    assert_equal %w[draft published], param['schema']['enum']
    assert_match(/draft/, param['description'])
    assert_match(/published/, param['description'])
  end

  # ── File upload → binary schema ────────────────────────────────────────

  def test_file_upload_converted_to_binary
    register_test_class_with_definitions([
                                           {
                                             path_item: { template: '/uploads' },
                                             operation: {
                                               verb: :post, summary: 'Upload',
                                               consumes: ['multipart/form-data'],
                                               parameters: [{ name: 'file', in: :formData, schema: { type: :file } }]
                                             },
                                             response: { code: '201', description: 'Created' },
                                             openapi_spec: nil
                                           }
                                         ])

    generator = Miniswag::OpenapiGenerator.new
    generator.generate!

    file_path = File.join(@tmpdir, 'v1/openapi.json')
    doc = JSON.parse(File.read(file_path))
    operation = doc['paths']['/uploads']['post']
    file_schema = operation['requestBody']['content']['multipart/form-data']['schema']['properties']['file']
    assert_equal 'string', file_schema['type']
    assert_equal 'binary', file_schema['format']
  end

  # ── Request examples ───────────────────────────────────────────────────

  def test_request_examples_in_request_body
    register_test_class_with_definitions([
                                           {
                                             path_item: { template: '/blogs' },
                                             operation: {
                                               verb: :post, summary: 'Create',
                                               consumes: ['application/json'],
                                               parameters: [{ name: 'blog', in: :body, schema: { type: :object }, required: true }],
                                               request_examples: [
                                                 { value: { title: 'Hello' }, summary: 'Basic blog', name: 'basic' }
                                               ]
                                             },
                                             response: { code: '201', description: 'Created' },
                                             openapi_spec: nil
                                           }
                                         ])

    generator = Miniswag::OpenapiGenerator.new
    generator.generate!

    file_path = File.join(@tmpdir, 'v1/openapi.json')
    doc = JSON.parse(File.read(file_path))
    operation = doc['paths']['/blogs']['post']
    examples = operation['requestBody']['content']['application/json']['examples']
    assert examples.key?('basic')
    assert_equal({ 'title' => 'Hello' }, examples['basic']['value'])
  end

  # ── Consumes/produces removed from operation ───────────────────────────

  def test_consumes_produces_removed_from_output
    register_test_class_with_definitions([
                                           {
                                             path_item: { template: '/blogs' },
                                             operation: {
                                               verb: :get, summary: 'List',
                                               consumes: ['application/json'],
                                               produces: ['application/json'],
                                               parameters: []
                                             },
                                             response: { code: '200', description: 'OK' },
                                             openapi_spec: nil
                                           }
                                         ])

    generator = Miniswag::OpenapiGenerator.new
    generator.generate!

    file_path = File.join(@tmpdir, 'v1/openapi.json')
    doc = JSON.parse(File.read(file_path))
    operation = doc['paths']['/blogs']['get']
    refute operation.key?('consumes')
    refute operation.key?('produces')
  end

  # ── formData with encoding ─────────────────────────────────────────────

  def test_form_data_with_encoding
    register_test_class_with_definitions([
                                           {
                                             path_item: { template: '/uploads' },
                                             operation: {
                                               verb: :post, summary: 'Upload',
                                               consumes: ['multipart/form-data'],
                                               parameters: [
                                                 { name: 'file', in: :formData, schema: { type: :file },
                                                   encoding: { contentType: ['image/png', 'image/jpeg'] } }
                                               ]
                                             },
                                             response: { code: '201', description: 'Created' },
                                             openapi_spec: nil
                                           }
                                         ])

    generator = Miniswag::OpenapiGenerator.new
    generator.generate!

    file_path = File.join(@tmpdir, 'v1/openapi.json')
    doc = JSON.parse(File.read(file_path))
    content = doc['paths']['/uploads']['post']['requestBody']['content']['multipart/form-data']
    assert content.key?('encoding')
    assert_equal 'image/png,image/jpeg', content['encoding']['file']['contentType']
  end

  # ── formData required sets requestBody required ────────────────────────

  def test_form_data_required_sets_request_body_required
    register_test_class_with_definitions([
                                           {
                                             path_item: { template: '/blogs' },
                                             operation: {
                                               verb: :post, summary: 'Create',
                                               consumes: ['multipart/form-data'],
                                               parameters: [
                                                 { name: 'title', in: :formData, schema: { type: :string }, required: true }
                                               ]
                                             },
                                             response: { code: '201', description: 'Created' },
                                             openapi_spec: nil
                                           }
                                         ])

    generator = Miniswag::OpenapiGenerator.new
    generator.generate!

    file_path = File.join(@tmpdir, 'v1/openapi.json')
    doc = JSON.parse(File.read(file_path))
    request_body = doc['paths']['/blogs']['post']['requestBody']
    assert_equal true, request_body['required']
  end

  # ── Type upgrade (type → schema.type) ──────────────────────────────────

  def test_type_upgrade_to_schema
    register_test_class_with_definitions([
                                           {
                                             path_item: { template: '/blogs', parameters: [{ type: :string }] },
                                             operation: { verb: :get, summary: 'List',
                                                          parameters: [{ type: :string }] },
                                             response: { code: '200', description: 'OK',
                                                         headers: { 'X-Custom' => { type: :string } } },
                                             openapi_spec: nil
                                           }
                                         ])

    generator = Miniswag::OpenapiGenerator.new
    generator.generate!

    file_path = File.join(@tmpdir, 'v1/openapi.json')
    doc = JSON.parse(File.read(file_path))
    # Operation-level params should have schema instead of type
    op_param = doc['paths']['/blogs']['get']['parameters'].first
    assert op_param.key?('schema')
    refute op_param.key?('type')
    # Path-level params
    path_param = doc['paths']['/blogs']['parameters'].first
    assert path_param.key?('schema')
    # Response headers
    header = doc['paths']['/blogs']['get']['responses']['200']['headers']['X-Custom']
    assert header.key?('schema')
  end
end
