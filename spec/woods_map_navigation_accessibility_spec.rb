# frozen_string_literal: true

require 'open3'
require 'tmpdir'

RSpec.describe WoodsMap do
  it 'honors filtered rows and contains modal keyboard focus with the shipped CSS and controllers' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']

    expect(browser_result).to eq(
      'paths' => %w[lib/shared/a.rb lib/shared/b.rb], 'count' => '3 of 3',
      'unresolvedVisible' => true, 'unresolvedCount' => '0 of 3',
      'forwardWrapped' => true, 'backwardWrapped' => true, 'restored' => true,
      'modalShortcutIgnored' => true, 'ordinaryShortcutOpens' => true
    )
  end

  def browser_result
    Dir.mktmpdir('woods-map-navigation') do |directory|
      fixture = File.join(directory, 'navigation.html')
      File.write(fixture, browser_fixture)
      output, _error, status = Open3.capture3(
        ENV.fetch('WOODS_MAP_BROWSER'), '--headless', '--disable-gpu', '--disable-background-networking',
        '--no-first-run', "--user-data-dir=#{File.join(directory, 'profile')}", '--dump-dom', "file://#{fixture}"
      )
      result = Nokogiri::HTML(output).at_css('#result')
      raise 'Browser regression did not produce results' unless status.success? && result && !result.text.empty?

      JSON.parse(result.text)
    end
  end

  def browser_fixture
    root = File.expand_path('..', __dir__)
    style_root = File.join(root, 'app/assets/stylesheets/woods_map')
    styles = %w[tokens.css map.css].map { |name| File.read(File.join(style_root, name)) }.join("\n")
    scripts = %w[tree sheet palette].map { |name| controller_source(root, name) }
    scripts << File.read(File.join(root, 'spec/javascript/navigation_accessibility_runner.js'))
    "<!doctype html><html lang=\"en\"><head><style>#{styles}</style></head>" \
      "<body><script>class Controller {}\n#{scripts.join("\n")}</script></body></html>"
  end

  def controller_source(root, name)
    File.read(File.join(root, "app/javascript/woods_map/controllers/#{name}_controller.js"))
        .sub(/\Aimport[^\n]+\n/, '').sub('export default class', "class #{name.capitalize}Controller")
  end
end
