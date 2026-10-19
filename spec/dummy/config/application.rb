# frozen_string_literal: true

require 'action_controller/railtie'
require 'woods_map'

module Dummy
  # Minimal host: no database, no asset pipeline, the engine mounted at /woods.
  class Application < Rails::Application
    config.root = File.expand_path('..', __dir__)
    config.eager_load = false
    config.secret_key_base = 'woods-map-dummy-secret-key-base-0123456789abcdef0123456789abcdef'
    config.hosts.clear if config.respond_to?(:hosts)
    config.logger = Logger.new(File::NULL)
    # Request specs post the token form without a CSRF token; the engine's
    # origin check is exercised separately and still runs.
    config.action_controller.allow_forgery_protection = false
    config.action_dispatch.show_exceptions = :none if config.respond_to?(:action_dispatch)
  end
end
