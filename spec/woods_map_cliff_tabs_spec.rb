# frozen_string_literal: true

require 'open3'
require 'tmpdir'

RSpec.describe WoodsMap do
  it 'starts a narrow tab row scrolled to the current tab with the shipped CSS and cliff controller' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']

    expect(cliff_result).to eq('overflows' => true, 'currentVisible' => true, 'firstUnscrolled' => true)
  end

  def cliff_result
    Dir.mktmpdir('woods-map-cliff') do |directory|
      fixture = File.join(directory, 'cliff.html')
      File.write(fixture, cliff_fixture)
      output, _error, status = Open3.capture3(
        ENV.fetch('WOODS_MAP_BROWSER'), '--headless', '--disable-gpu', '--disable-background-networking',
        '--no-first-run', "--user-data-dir=#{File.join(directory, 'profile')}", '--dump-dom', "file://#{fixture}"
      )
      result = Nokogiri::HTML(output).at_css('#result')
      raise 'Browser regression did not produce results' unless status.success? && result && !result.text.empty?

      JSON.parse(result.text)
    end
  end

  def cliff_fixture
    root = File.expand_path('..', __dir__)
    style_root = File.join(root, 'app/assets/stylesheets/woods_map')
    styles = %w[tokens.css map.css].map { |name| File.read(File.join(style_root, name)) }.join("\n")
    script = File.read(File.join(root, 'app/javascript/woods_map/controllers/cliff_controller.js'))
                 .sub(/\Aimport[^\n]+\n/, '').sub('export default class', 'class CliffController')
    runner = File.read(File.join(root, 'spec/javascript/cliff_tabs_runner.js'))
    "<!doctype html><html lang=\"en\"><head><style>#{styles}</style></head>" \
      "<body><script>class Controller {}\n#{script}\n#{runner}</script></body></html>"
  end
end
