# frozen_string_literal: true

Miniswag::Api.configure do |c|
  # Specify a root folder where OpenAPI JSON/YAML files are located.
  # This is used by the middleware to serve requests for API descriptions.
  c.openapi_root = Rails.root.join('openapi').to_s

  # Inject a lambda to alter the returned OpenAPI prior to serialization.
  # The function will have access to the rack env for the current request.
  # For example, you could leverage this to dynamically assign the "host" property:
  #
  # c.openapi_filter = lambda { |swagger, env| swagger['host'] = env['HTTP_HOST'] }
end
