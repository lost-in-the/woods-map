# frozen_string_literal: true

require 'open3'
require 'tmpdir'

RSpec.describe 'Reading settings in Chromium', type: :request do
  it 'keeps wrap opt-in in one region, applies size and the editor link, refuses unsafe schemes' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM regression' unless ENV['WOODS_MAP_BROWSER']

    result = settings_browser_result
    expect(result.fetch('cases')).to eq(4)
    expect(result.fetch('failures')).to eq([])
  end

  def settings_browser_result
    Dir.mktmpdir('woods-map-settings') do |directory|
      fixture = File.join(directory, 'settings.html')
      File.write(fixture, settings_browser_fixture)
      output, error, status = Open3.capture3(
        ENV.fetch('WOODS_MAP_BROWSER'), '--headless', '--disable-gpu', '--disable-background-networking',
        '--no-first-run', '--virtual-time-budget=30000', "--user-data-dir=#{File.join(directory, 'profile')}",
        '--dump-dom', "file://#{fixture}"
      )
      result = Nokogiri::HTML(output).at_css('#result')
      unless status.success? && result && !result.text.empty?
        raise "Settings regression did not produce results: #{error}"
      end

      JSON.parse(result.text)
    end
  end

  def settings_browser_fixture
    root = File.expand_path('..', __dir__)
    styles = %w[tokens.css map.css].map { |name| File.read(File.join(root, 'app/assets/stylesheets/woods_map', name)) }
    get '/woods/units/model/User', params: { lens: 'written' }
    follow_redirect!
    controller = File.read(File.join(root, 'app/javascript/woods_map/controllers/settings_controller.js'))
    data = JSON.generate(html: html_response_document.at_css('main').inner_html, styles: styles.join("\n"),
                         controller: controller).gsub('</', '<\\/')
    runner = File.read(File.join(root, 'spec/javascript/settings_runner.js'))
    '<!doctype html><html lang="en"><body><pre id="result"></pre>' \
      "<script>const fixtureData = #{data};\n#{runner}</script></body></html>"
  end
end
