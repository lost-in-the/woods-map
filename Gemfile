# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

# Woods 2.2 is unreleased while M0 lands. Prefer a sibling checkout (the
# woods-testbed layout), otherwise follow the Woods main branch.
sibling = File.expand_path('../woods', __dir__)
if File.directory?(sibling)
  gem 'woods', path: sibling
else
  gem 'woods', github: 'lost-in-the/woods', branch: 'main'
end

group :development, :test do
  # The opt-in end-to-end spec boots the dummy host under Puma
  # (WOODS_MAP_RUN_HTTP_SERVER=1, spec/woods_map/engine_http_server_spec.rb).
  gem 'puma', '>= 5.0'
  # The guide (M7) runs on RubyLLM 2.1, which needs Ruby 3.2. The gem never
  # depends on it; hosts add it. Specs load it where the Ruby allows.
  gem 'rails', '>= 6.0'
  gem 'rake', '~> 13.0'
  gem 'rspec', '~> 3.12'
  gem 'rspec-rails', '>= 6.0'
  gem 'rubocop', '~> 1.50'
  gem 'rubocop-rails', '~> 2.19'
  gem 'rubocop-rspec', '~> 3.9'
  gem 'ruby_llm', '~> 2.1' if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.2')
end
