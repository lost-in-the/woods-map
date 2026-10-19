# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'
require File.expand_path('dummy/config/environment', __dir__)
require 'rspec/rails'

FIXTURE_INDEX = File.expand_path('fixtures/index', __dir__)

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  config.before do
    WoodsMap.reset_configuration!
    WoodsMap.configuration.index_dir = FIXTURE_INDEX
  end
end
