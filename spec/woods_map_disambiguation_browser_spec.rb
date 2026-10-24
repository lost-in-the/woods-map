# frozen_string_literal: true

require 'open3'
require 'tmpdir'

RSpec.describe 'Disambiguation popover keyboard' do # rubocop:disable RSpec/DescribeClass
  it 'opens, moves focus with the arrows and closes back to its reference' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM regression' unless ENV['WOODS_MAP_BROWSER']

    result = browser_result
    expect(result.fetch('cases')).to eq(11)
    expect(result.fetch('failures')).to eq([])
  end

  def browser_result
    Dir.mktmpdir('woods-map-disambiguation') do |directory|
      fixture = File.join(directory, 'disambiguation.html')
      File.write(fixture, browser_fixture)
      output, error, status = Open3.capture3(
        ENV.fetch('WOODS_MAP_BROWSER'), '--headless', '--disable-gpu', '--disable-background-networking',
        '--no-first-run', '--virtual-time-budget=5000', "--user-data-dir=#{File.join(directory, 'profile')}",
        '--dump-dom', "file://#{fixture}"
      )
      result = Nokogiri::HTML(output).at_css('#result')
      unless status.success? && result && !result.text.empty?
        raise "Disambiguation regression did not produce results: #{error}"
      end

      JSON.parse(result.text)
    end
  end

  # The shipped controller and styles, its import line removed, run against a stub Controller base.
  def browser_fixture
    root = File.expand_path('..', __dir__)
    styles = %w[tokens.css map.css].map { |name| File.read(File.join(root, 'app/assets/stylesheets/woods_map', name)) }
    controller = File.read(File.join(root, 'app/javascript/woods_map/controllers/disambiguation_controller.js'))
                     .sub(/\Aimport[^\n]+\n/, '').sub('export default class', 'class DisambiguationController')
    runner = File.read(File.join(root, 'spec/javascript/disambiguation_runner.js'))
    "<!doctype html><html lang=\"en\"><head><style>#{styles.join("\n")}</style></head>" \
      "<body><pre id=\"result\"></pre><script>class Controller {}\n#{controller}\n#{runner}</script></body></html>"
  end
end
