# frozen_string_literal: true

RSpec.describe Gem::Specification do
  it 'ships the documentation the README links alongside runtime assets' do
    root = File.expand_path('../..', __dir__)
    files = described_class.load(File.join(root, 'woods-map.gemspec')).files
    links = File.read(File.join(root, 'README.md')).scan(%r{\]\((docs/[^)#]+)(?:#[^)]*)?\)}).flatten
    expect(files).to include('docs/DEPLOYMENT.md', 'docs/THREAT_MODEL.md', *links.reject { |link| link.end_with?('/') })
    expect(files).to include(a_string_starting_with('docs/design/'))
    expect(files).to include(*Dir.chdir(root) { Dir['vendor/fonts/**/*.woff2', 'vendor/javascript/**/*.js'] })
  end
end
