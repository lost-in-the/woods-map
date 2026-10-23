# frozen_string_literal: true

require 'open3'
require 'tmpdir'

RSpec.describe 'Keyboard help focus and shortcuts', type: :request do
  it 'opens and dismisses help without stealing component or editing keys' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM regression' unless ENV['WOODS_MAP_BROWSER']

    result = help_browser_result
    expect(result.fetch('cases')).to eq(8)
    expect(result.fetch('failures')).to eq([])
  end

  def help_browser_result
    Dir.mktmpdir('woods-map-help') do |directory|
      fixture = File.join(directory, 'help.html')
      File.write(fixture, help_browser_fixture)
      output, error, status = Open3.capture3(
        ENV.fetch('WOODS_MAP_BROWSER'), '--headless', '--disable-gpu', '--disable-background-networking',
        '--no-first-run', '--virtual-time-budget=30000', "--user-data-dir=#{File.join(directory, 'profile')}",
        '--dump-dom', "file://#{fixture}"
      )
      result = Nokogiri::HTML(output).at_css('#result')
      raise "Help regression did not produce results: #{error}" unless status.success? && result && !result.text.empty?

      JSON.parse(result.text)
    end
  end

  def help_browser_fixture
    root = File.expand_path('..', __dir__)
    styles = %w[tokens.css map.css].map do |name|
      File.read(File.join(root, 'app/assets/stylesheets/woods_map', name))
    end.join("\n")
    controllers = %w[help keys palette].index_with do |name|
      File.read(File.join(root, "app/javascript/woods_map/controllers/#{name}_controller.js"))
    end
    runner = File.read(File.join(root, 'spec/javascript/help_accessibility_runner.js'))
    data = JSON.generate(pages: help_pages, styles: styles, controllers: controllers).gsub('</', '<\\/')
    '<!doctype html><html lang="en"><body><pre id="result"></pre>' \
      "<script>const fixtureData = #{data};\n#{runner}</script></body></html>"
  end

  def help_pages
    %w[/woods /catalog/map].map do |mount|
      get "#{mount}/units/model/User", params: { lens: 'written' }
      follow_redirect! if response.redirect?
      document = html_response_document
      { mount: mount, html: document.at_css('.bar').to_html + document.at_css('#wm-keyboard-help').to_html }
    end
  end
end
