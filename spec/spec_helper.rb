# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'
require File.expand_path('dummy/config/environment', __dir__)
require 'rspec/rails'
require_relative 'support/html_response'
require_relative 'support/landscape_index'
require_relative 'support/flow_index'
require_relative 'support/package_index'
require_relative 'support/m3_exit_check'
require_relative 'support/fake_guide_chat'
require_relative 'support/woods_line_stats'

RSpec::Matchers.define_negated_matcher :not_include, :include

FIXTURE_INDEX = File.expand_path('fixtures/index', __dir__)

RSpec.configure do |config|
  config.include WoodsMap::HtmlResponse, type: :request
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  # Binds a port and drives the dummy host under Puma (M8); opt in with
  # WOODS_MAP_RUN_HTTP_SERVER=1, as Woods does with WOODS_RUN_HTTP_SERVER.
  config.filter_run_excluding(http_server: true) unless ENV['WOODS_MAP_RUN_HTTP_SERVER']
  config.order = :random
  Kernel.srand config.seed

  config.before do
    WoodsMap.reset_configuration!
    WoodsMap.configuration.index_dir = FIXTURE_INDEX
    WoodsMap::GenerationFacets.reset!
    # Specs stub a repository's graph under the fixture's generation key.
    WoodsMap::TreesController.reset!
  end

  # The token-less loopback mode requires a loopback Host (DNS rebinding,
  # M8); rack-test's default www.example.com is the rebinding case itself.
  config.before(type: :request) { host! 'localhost' }
end
