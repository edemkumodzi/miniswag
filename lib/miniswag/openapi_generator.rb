# frozen_string_literal: true

require 'active_support/core_ext/hash/deep_merge'
require 'json'
require 'yaml'
require 'fileutils'

module Miniswag
  # Collects metadata from test definitions and generates OpenAPI spec files.
  # This is the Minitest equivalent of rswag's OpenapiFormatter.
  class OpenapiGenerator
    def initialize(config = Miniswag.config)
      @config = config
    end

    def generate!
      @config.validate!

      # Process all registered test class metadata
      Miniswag.registered_test_classes.each do |test_class|
        test_class.miniswag_test_definitions.each do |metadata|
          next if metadata[:document] == false || metadata.dig(:response, :document) == false
          next unless metadata.key?(:response)

          openapi_spec = @config.get_openapi_spec(metadata[:openapi_spec])
          raise ConfigurationError, 'Unsupported OpenAPI version' unless doc_version(openapi_spec)&.start_with?('3')

          upgrade_request_type!(metadata)
          upgrade_response_produces!(openapi_spec, metadata)
          openapi_spec.deep_merge!(metadata_to_openapi(metadata))
        end
      end

      # Post-process and write files
      @config.openapi_specs.each do |url_path, doc|
        parse_parameters(doc)
        file_path = File.join(@config.openapi_root, url_path)
        dirname = File.dirname(file_path)
        FileUtils.mkdir_p(dirname) unless File.exist?(dirname)
        File.open(file_path, 'w') do |file|
          file.write(pretty_generate(doc))
        end
        puts "Miniswag: OpenAPI doc generated at #{file_path}"
      end
    end

    private

    def doc_version(doc)
      doc[:openapi]
    end

    def pretty_generate(doc)
      if @config.openapi_format == :yaml
        clean_doc = JSON.parse(JSON.pretty_generate(doc))
        YAML.dump(clean_doc)
      else
        JSON.pretty_generate(doc)
      end
    end

    def metadata_to_openapi(metadata)
      response_code = metadata[:response][:code]
      response = metadata[:response].reject { |k, _v| %i[code document].include?(k) }
      verb = metadata[:operation][:verb]
      operation = metadata[:operation]
                  .reject { |k, _v| k == :verb }
                  .merge(responses: { response_code => response })
      path_template = metadata[:path_item][:template]
      path_item = metadata[:path_item]
                  .reject { |k, _v| k == :template }
                  .merge(verb => operation)
      { paths: { path_template => path_item } }
    end

    def upgrade_response_produces!(openapi_spec, metadata)
      mime_list = Array(metadata[:operation][:produces] || openapi_spec[:produces])
      target_node = metadata[:response]
      upgrade_content!(mime_list, target_node)
      metadata[:response].delete(:schema)
    end

    def upgrade_content!(mime_list, target_node)
      schema = target_node[:schema]
      return if mime_list.empty? || schema.nil?

      target_node[:content] ||= {}
      mime_list.each do |mime_type|
        (target_node[:content][mime_type] ||= {}).merge!(schema: schema)
      end
    end

    def upgrade_request_type!(metadata)
      operation_nodes = metadata[:operation][:parameters] || []
      path_nodes = metadata[:path_item][:parameters] || []
      header_node = metadata[:response][:headers] || {}
      (operation_nodes + path_nodes + header_node.values).each do |node|
        if node && node[:type] && node[:schema].nil?
          node[:schema] = { type: node[:type] }
          node.delete(:type)
        end
      end
    end

    def remove_invalid_operation_keys!(value)
      return unless value.is_a?(Hash)

      value.delete(:consumes) if value[:consumes]
      value.delete(:produces) if value[:produces]
      value.delete(:request_examples) if value[:request_examples]
    end

    def parse_parameters(doc)
      doc[:paths]&.each_pair do |_k, path|
        path.each_pair do |_verb, endpoint|
          is_hash = endpoint.is_a?(Hash)
          if is_hash && endpoint[:parameters]
            mime_list = endpoint[:consumes] || doc[:consumes]
            parse_endpoint(endpoint, mime_list)
          end
          remove_invalid_operation_keys!(endpoint)
        end
      end
    end

    def parse_endpoint(endpoint, mime_list)
      parameters = endpoint[:parameters]
      parameters.each do |parameter|
        set_parameter_schema(parameter)
        convert_file_parameter(parameter)
        parse_enum(parameter)
      end
      parameters.select { |p| parameter_in_form_data_or_body?(p) }.each do |parameter|
        parse_form_data_or_body_parameter(endpoint, parameter, mime_list)
        parameters.delete(parameter)
      end
      parameters.each { |p| p.delete(:schema) if p[:schema].blank? }
    end

    def set_parameter_schema(parameter)
      parameter[:schema] ||= {}
      if parameter[:schema].key?(:required) && parameter[:schema][:required] == true
        parameter[:required] = parameter[:schema].delete(:required)
      end
      parameter[:schema][:type] = parameter.delete(:type) if parameter.key?(:type)
    end

    def parameter_in_form_data_or_body?(p)
      p[:in] == :formData || parameter_in_body?(p)
    end

    def parameter_in_body?(p)
      p[:in] == :body
    end

    def parse_form_data_or_body_parameter(endpoint, parameter, mime_list)
      unless mime_list
        raise ConfigurationError,
              'A body or form data parameters are specified without a Media Type for the content'
      end
      add_request_body(endpoint)
      desc = parameter.delete(:description)
      parameter[:schema][:description] = desc if desc
      mime_list.each do |mime|
        endpoint[:requestBody][:content][mime] ||= {}
        mime_config = endpoint[:requestBody][:content][mime]
        next unless mime_config[:schema].nil? || mime_config.dig(:schema, :properties)

        set_mime_config(mime_config, parameter)
        set_mime_examples(mime_config, endpoint)
        set_request_body_required(mime_config, endpoint, parameter)
      end
    end

    def add_request_body(endpoint)
      return if endpoint.dig(:requestBody, :content)

      endpoint[:requestBody] = { content: {} }
    end

    def set_request_body_required(mime_config, endpoint, parameter)
      return unless parameter[:required]

      endpoint[:requestBody][:required] = true
      return if parameter_in_body?(parameter)

      if parameter[:name]
        mime_config[:schema][:required] ||= []
        mime_config[:schema][:required] << parameter[:name].to_s
      else
        mime_config[:schema][:required] = true
      end
    end

    def convert_file_parameter(parameter)
      return unless parameter[:schema][:type] == :file

      parameter[:schema][:type] = :string
      parameter[:schema][:format] = :binary
    end

    def set_mime_config(mime_config, parameter)
      schema_with_form_properties = parameter[:name] && !parameter_in_body?(parameter)
      mime_config[:schema] ||= schema_with_form_properties ? { type: :object, properties: {} } : parameter[:schema]
      return unless schema_with_form_properties

      mime_config[:schema][:properties][parameter[:name]] = parameter[:schema]
      set_mime_encoding(mime_config, parameter)
    end

    def set_mime_encoding(mime_config, parameter)
      return unless parameter[:encoding]

      encoding = parameter[:encoding].dup
      encoding[:contentType] = encoding[:contentType].join(',') if encoding[:contentType].is_a?(Array)
      mime_config[:encoding] ||= {}
      mime_config[:encoding][parameter[:name]] = encoding
    end

    def set_mime_examples(mime_config, endpoint)
      examples = endpoint[:request_examples]
      return unless examples

      examples.each do |ex|
        mime_config[:examples] ||= {}
        mime_config[:examples][ex[:name]] = {
          summary: ex[:summary] || endpoint[:summary],
          value: ex[:value]
        }
      end
    end

    def parse_enum(parameter)
      return unless parameter.key?(:enum)

      enum = parameter.delete(:enum)
      parameter[:schema] ||= {}
      parameter[:schema][:enum] = enum.is_a?(Hash) ? enum.keys.map(&:to_s) : enum
      parameter[:description] = generate_enum_description(parameter, enum) if enum.is_a?(Hash)
    end

    def generate_enum_description(param, enum)
      enum_description = "#{param[:description]}:\n "
      enum.each do |k, v|
        enum_description += "* `#{k}` #{v}\n "
      end
      enum_description
    end
  end
end
