# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/hash/conversions'
require 'json'
require 'cgi'

module Miniswag
  class RequestFactory
    attr_accessor :metadata, :params, :headers

    def initialize(metadata, params = {}, headers = {}, config = Miniswag.config)
      @config = config
      @metadata = metadata
      @params = params.transform_keys(&:to_s)
      @headers = headers.transform_keys(&:to_s)
    end

    def build_request
      openapi_spec = @config.get_openapi_spec(metadata[:openapi_spec])
      parameters = expand_parameters(metadata, openapi_spec)
      {}.tap do |request|
        add_verb(request, metadata)
        add_path(request, metadata, openapi_spec, parameters)
        add_headers(request, metadata, openapi_spec, parameters)
        add_payload(request, parameters)
      end
    end

    private

    def expand_parameters(metadata, openapi_spec)
      operation_params = metadata[:operation][:parameters] || []
      path_item_params = metadata[:path_item][:parameters] || []
      security_params = derive_security_params(metadata, openapi_spec)
      (operation_params + path_item_params + security_params)
        .map { |p| p['$ref'] ? resolve_parameter(p['$ref'], openapi_spec) : p }
        .uniq { |p| p[:name] }
        .reject do |p|
          p[:required] == false &&
            !@headers.key?(p[:name].to_s) &&
            !@params.key?(p[:name].to_s)
        end
    end

    def derive_security_params(metadata, openapi_spec)
      requirements = metadata[:operation][:security] || openapi_spec[:security] || []
      scheme_names = requirements.flat_map(&:keys)
      schemes = security_version(scheme_names, openapi_spec)
      schemes.map do |scheme|
        param = scheme[:type] == :apiKey ? scheme.slice(:name, :in) : { name: 'Authorization', in: :header }
        param.merge(schema: { type: :string }, required: requirements.one?)
      end
    end

    def security_version(scheme_names, openapi_spec)
      components = openapi_spec[:components] || {}
      (components[:securitySchemes] || {}).slice(*scheme_names).values
    end

    def resolve_parameter(ref, openapi_spec)
      key = ref.sub('#/components/parameters/', '').to_sym
      definitions = (openapi_spec[:components] || {})[:parameters]
      raise "Referenced parameter '#{ref}' must be defined" unless definitions && definitions[key]

      definitions[key]
    end

    def add_verb(request, metadata)
      request[:verb] = metadata[:operation][:verb]
    end

    def base_path_from_servers(openapi_spec, use_server = :default)
      return '' if openapi_spec[:servers].nil? || openapi_spec[:servers].empty?

      server = openapi_spec[:servers].first
      variables = {}
      server.fetch(:variables, {}).each_pair { |k, v| variables[k] = v[use_server] }
      base_path = server[:url].gsub(/\{(.*?)\}/) { variables[::Regexp.last_match(1).to_sym] }
      URI(base_path).path
    end

    def add_path(request, metadata, openapi_spec, parameters)
      template = base_path_from_servers(openapi_spec) + metadata[:path_item][:template]
      request[:path] = template.tap do |path_template|
        parameters.select { |p| p[:in] == :path }.each do |p|
          param_value = @params.fetch(p[:name].to_s) do
            raise ArgumentError, "`#{p[:name]}` parameter key present in path but not provided in params"
          end
          path_template.gsub!("{#{p[:name]}}", param_value.to_s)
        end
        parameters.select { |p| p[:in] == :query && @params.key?(p[:name].to_s) }.each_with_index do |p, i|
          path_template.concat(i.zero? ? '?' : '&')
          path_template.concat(build_query_string_part(p, @params.fetch(p[:name].to_s), openapi_spec))
        end
      end
    end

    def build_query_string_part(param, value, _openapi_spec)
      name = param[:name]
      escaped_name = CGI.escape(name.to_s)
      return unless param[:schema]

      style = param[:style]&.to_sym || :form
      explode = param[:explode].nil? || param[:explode]
      type = param.dig(:schema, :type)&.to_sym
      case type
      when :object
        case style
        when :deepObject then { name => value }.to_query
        when :form
          return value.to_query if explode

          "#{escaped_name}=" + value.to_a.flatten.map { |v| CGI.escape(v.to_s) }.join(',')
        end
      when :array
        case explode
        when true
          value.to_a.flatten.map { |v| "#{escaped_name}=#{CGI.escape(v.to_s)}" }.join('&')
        else
          separator = case style
                      when :form then ','
                      when :spaceDelimited then '%20'
                      when :pipeDelimited then '|'
                      end
          "#{escaped_name}=" + value.to_a.flatten.map { |v| CGI.escape(v.to_s) }.join(separator)
        end
      else
        "#{escaped_name}=#{CGI.escape(value.to_s)}"
      end
    end

    def add_headers(request, metadata, openapi_spec, parameters)
      tuples = parameters
               .select { |p| p[:in] == :header }
               .map { |p| [p[:name], @params.fetch(p[:name].to_s, @headers.fetch(p[:name].to_s, '')).to_s] }

      produces = metadata[:operation][:produces] || openapi_spec[:produces]
      if produces
        accept = @headers.fetch('Accept', produces.first)
        tuples << ['Accept', accept]
      end

      consumes = metadata[:operation][:consumes] || openapi_spec[:consumes]
      if consumes
        content_type = @headers.fetch('Content-Type', consumes.first)
        tuples << ['Content-Type', content_type]
      end

      host = metadata[:operation][:host] || openapi_spec[:host]
      tuples << ['Host', host] if host.present?

      rack_formatted_tuples = tuples.map do |pair|
        [
          case pair[0]
          when 'Accept' then 'HTTP_ACCEPT'
          when 'Content-Type' then 'CONTENT_TYPE'
          when 'Authorization' then 'HTTP_AUTHORIZATION'
          when 'Host' then 'HTTP_HOST'
          else pair[0]
          end,
          pair[1]
        ]
      end
      request[:headers] = Hash[rack_formatted_tuples]
    end

    def add_payload(request, parameters)
      content_type = request[:headers]['CONTENT_TYPE']
      return if content_type.nil?

      request[:payload] = if ['application/x-www-form-urlencoded', 'multipart/form-data'].include?(content_type)
                            build_form_payload(parameters)
                          elsif %r{\Aapplication/([0-9A-Za-z._-]+\+json\z|json\z)}.match?(content_type)
                            build_json_payload(parameters)
                          else
                            build_raw_payload(parameters)
                          end
    end

    def build_form_payload(parameters)
      tuples = parameters
               .select { |p| p[:in] == :formData }
               .map { |p| [p[:name], @params.fetch(p[:name].to_s)] }
      Hash[tuples]
    end

    def build_raw_payload(parameters)
      body_param = parameters.find { |p| p[:in] == :body }
      return nil unless body_param

      @params.fetch(body_param[:name].to_s) do
        raise MissingParameterError, body_param[:name]
      end
    end

    def build_json_payload(parameters)
      build_raw_payload(parameters)&.to_json
    end
  end

  class MissingParameterError < StandardError
    attr_reader :body_param

    def initialize(body_param)
      @body_param = body_param
    end

    def message
      <<~MSG
        Missing parameter '#{body_param}'
        Please check your test. Ensure you provide the parameter in a `params` block.
      MSG
    end
  end
end
