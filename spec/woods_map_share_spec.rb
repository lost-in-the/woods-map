# frozen_string_literal: true

require 'open3'
require 'tmpdir'

RSpec.describe 'The Share menu in Chromium', type: :request do
  it 'opens from its button, copies the focus URL and each diagram, and closes by keyboard and outside clicks' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM regression' unless ENV['WOODS_MAP_BROWSER']

    result = share_browser_result
    expect(result.fetch('cases')).to eq(4)
    expect(result.fetch('failures')).to eq([])
  end

  def share_browser_result
    Dir.mktmpdir('woods-map-share') do |directory|
      fixture = File.join(directory, 'share.html')
      File.write(fixture, share_browser_fixture)
      output, error, status = Open3.capture3(
        ENV.fetch('WOODS_MAP_BROWSER'), '--headless', '--disable-gpu', '--disable-background-networking',
        '--no-first-run', '--virtual-time-budget=30000', "--user-data-dir=#{File.join(directory, 'profile')}",
        '--dump-dom', "file://#{fixture}"
      )
      result = Nokogiri::HTML(output).at_css('#result')
      raise "Share regression did not produce results: #{error}" unless status.success? && result && !result.text.empty?

      JSON.parse(result.text)
    end
  end

  def share_browser_fixture
    root = File.expand_path('..', __dir__)
    styles = %w[tokens.css map.css].map { |name| File.read(File.join(root, 'app/assets/stylesheets/woods_map', name)) }
    controllers = %w[share keys].index_with do |name|
      File.read(File.join(root, "app/javascript/woods_map/controllers/#{name}_controller.js"))
    end
    get '/woods/units/model/User/schema'
    data = JSON.generate(html: Nokogiri::HTML(response.body).at_css('main').inner_html, styles: styles.join("\n"),
                         controllers: controllers).gsub('</', '<\\/')
    runner = File.read(File.join(root, 'spec/javascript/share_runner.js'))
    '<!doctype html><html lang="en"><body><pre id="result"></pre>' \
      "<script>const fixtureData = #{data};\n#{runner}</script></body></html>"
  end
end
