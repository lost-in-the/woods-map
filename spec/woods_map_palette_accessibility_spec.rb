# frozen_string_literal: true

require 'open3'
require 'tmpdir'

RSpec.describe 'Palette focus and semantics', type: :request do
  it 'dismisses on focus exit and Escape while keeping choices and pointer navigation usable' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM regression' unless ENV['WOODS_MAP_BROWSER']

    result = palette_browser_result
    expect(result.fetch('cases')).to eq(16)
    expect(result.fetch('failures')).to eq([])
  end

  def palette_browser_result
    Dir.mktmpdir('woods-map-palette') do |directory|
      fixture = File.join(directory, 'palette.html')
      File.write(fixture, palette_browser_fixture)
      output, error, status = Open3.capture3(
        ENV.fetch('WOODS_MAP_BROWSER'), '--headless', '--disable-gpu', '--disable-background-networking',
        '--no-first-run', '--virtual-time-budget=30000', "--user-data-dir=#{File.join(directory, 'profile')}",
        '--dump-dom', "file://#{fixture}"
      )
      result = Nokogiri::HTML(output).at_css('#result')
      unless status.success? && result && !result.text.empty?
        raise "Palette regression did not produce results: #{error}"
      end

      JSON.parse(result.text)
    end
  end

  def palette_browser_fixture
    root = File.expand_path('..', __dir__)
    styles = %w[tokens.css map.css].map do |name|
      File.read(File.join(root, 'app/assets/stylesheets/woods_map', name))
    end.join("\n")
    controller = File.read(File.join(root, 'app/javascript/woods_map/controllers/palette_controller.js'))
    runner = File.read(File.join(root, 'spec/javascript/palette_accessibility_runner.js'))
    data = JSON.generate(pages: palette_pages, styles: styles, controller: controller).gsub('</', '<\\/')
    '<!doctype html><html lang="en"><body><pre id="result"></pre>' \
      "<script>const fixtureData = #{data};\n#{runner}</script></body></html>"
  end

  def palette_pages
    %w[/woods /catalog/map].product(%w[written effective]).map do |mount, lens|
      get "#{mount}/units/model/User", params: { lens: lens }
      follow_redirect! if response.redirect?
      document = html_response_document
      { mount: mount, lens: lens, html: document.at_css('.bar').to_html + document.at_css('.cvwrap').to_html }
    end
  end
end
