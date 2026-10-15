# frozen_string_literal: true

require_relative 'lib/woods_map/version'

Gem::Specification.new do |spec|
  spec.name          = 'woods-map'
  spec.version       = WoodsMap::VERSION
  spec.authors       = ['Leah Armstrong']
  spec.email         = ['info@leah.wtf']

  spec.summary       = 'In-app code-comprehension explorer over a published Woods index'
  spec.description   = <<~DESC
    Woods Map is a Rails Engine that turns a published Woods index into a
    code-comprehension explorer mounted inside the application: read each unit
    as Rails runs it, follow references and data passages, see lifecycles,
    relationship graphs, schema and history, and share change-impact reports.
  DESC
  spec.homepage      = 'https://github.com/lost-in-the/woods-map'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri'] = "#{spec.homepage}/issues"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir[
    'lib/**/*', 'app/**/*', 'config/**/*', 'vendor/javascript/**/*',
    'docs/design/*.md', 'LICENSE.txt', 'README.md', 'CHANGELOG.md', 'CONTRIBUTING.md'
  ]
  spec.require_paths = ['lib']

  # Floors match Woods (railties >= 6.0, Ruby >= 3.0). The engine serves its
  # own JavaScript and emits its own import map, so there is no dependency on
  # importmap-rails, turbo-rails or an asset pipeline.
  spec.add_dependency 'railties', '>= 6.0', '< 9'
  # Server-side highlighting; the reference spans are injected after rouge runs.
  spec.add_dependency 'rouge', '>= 4.0', '< 6'
  # The M0 extraction additions (reference spans, method table, commit table,
  # impact report) land in Woods 2.2.
  spec.add_dependency 'woods', '>= 2.2.0.alpha', '< 3'
end
