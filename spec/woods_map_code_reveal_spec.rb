# frozen_string_literal: true

require 'open3'
require 'tmpdir'

RSpec.describe WoodsMap do
  it 'brings a source-line permalink into view on load and on later hash changes' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']

    expect(reveal_result).to eq('initialScrolled' => true, 'initialVisible' => true, 'hashchangeVisible' => true,
                                'backwardVisible' => true, 'missingIsQuiet' => true)
  end

  def reveal_result
    Dir.mktmpdir('woods-map-reveal') do |directory|
      fixture = File.join(directory, 'reveal.html')
      File.write(fixture, reveal_fixture)
      output, _error, status = Open3.capture3(
        ENV.fetch('WOODS_MAP_BROWSER'), '--headless', '--disable-gpu', '--disable-background-networking',
        '--no-first-run', '--virtual-time-budget=5000', "--user-data-dir=#{File.join(directory, 'profile')}",
        '--dump-dom', "file://#{fixture}#L53"
      )
      result = Nokogiri::HTML(output).at_css('#result')
      raise 'Browser regression did not produce results' unless status.success? && result && !result.text.empty?

      JSON.parse(result.text)
    end
  end

  def reveal_fixture
    root = File.expand_path('..', __dir__)
    style_root = File.join(root, 'app/assets/stylesheets/woods_map')
    styles = %w[tokens.css map.css].map { |name| File.read(File.join(style_root, name)) }.join("\n")
    controller = File.join(root, 'app/javascript/woods_map/controllers/reveal_controller.js')
    script = File.read(controller).sub(/\Aimport[^\n]+\n/, '').sub('export default class', 'class RevealController')
    runner = File.read(File.join(root, 'spec/javascript/code_reveal_runner.js'))
    "<!doctype html><html lang=\"en\"><head><style>#{styles}</style></head>" \
      "<body><script>class Controller {}\n#{script}\n(async () => {\n#{runner}\n})()</script></body></html>"
  end
end
