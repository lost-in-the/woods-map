# frozen_string_literal: true

require 'open3'
require 'tmpdir'
require_relative 'support/hover_card_index'

RSpec.describe 'Hover cards in Chromium', type: :request do
  include HoverCardIndex

  it 'opens on focus and on hover within 100 ms, describes the link and closes on Escape' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM regression' unless ENV['WOODS_MAP_BROWSER']

    result = card_browser_result
    expect(result.fetch('cases')).to eq(4)
    expect(result.fetch('failures')).to eq([])
  end

  def card_browser_result
    Dir.mktmpdir('woods-map-cards') do |directory|
      fixture = File.join(directory, 'cards.html')
      File.write(fixture, card_browser_fixture)
      output, error, status = Open3.capture3(
        ENV.fetch('WOODS_MAP_BROWSER'), '--headless', '--disable-gpu', '--disable-background-networking',
        '--no-first-run', '--virtual-time-budget=30000', "--user-data-dir=#{File.join(directory, 'profile')}",
        '--dump-dom', "file://#{fixture}"
      )
      result = Nokogiri::HTML(output).at_css('#result')
      unless status.success? && result && !result.text.empty?
        raise "Hover card regression did not produce results: #{error}"
      end

      JSON.parse(result.text)
    end
  end

  def card_browser_fixture
    root = File.expand_path('..', __dir__)
    styles = %w[tokens.css map.css].map { |name| File.read(File.join(root, 'app/assets/stylesheets/woods_map', name)) }
    controllers = %w[card tooltip].index_with do |name|
      File.read(File.join(root, "app/javascript/woods_map/controllers/#{name}_controller.js"))
    end
    get '/woods/units/model/Caller'
    data = JSON.generate(html: html_response_document.at_css('.body').to_html, styles: styles.join("\n"),
                         controllers: controllers).gsub('</', '<\\/')
    runner = File.read(File.join(root, 'spec/javascript/hover_card_runner.js'))
    '<!doctype html><html lang="en"><body><pre id="result"></pre>' \
      "<script>const fixtureData = #{data};\n#{runner}</script></body></html>"
  end
end
