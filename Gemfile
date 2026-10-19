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
  gem 'rails', '>= 6.0'
  gem 'rake', '~> 13.0'
  gem 'rspec', '~> 3.12'
  gem 'rspec-rails', '>= 6.0'
  gem 'rubocop', '~> 1.50'
  gem 'rubocop-rails', '~> 2.19'
  gem 'rubocop-rspec', '~> 3.9'
end
