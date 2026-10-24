# frozen_string_literal: true

require 'open3'
require 'tmpdir'

RSpec.describe 'The History brush in Chromium', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  before { WoodsMap::CommitLedger.reset! }

  it 'picks a span by drag and by Shift+arrows on the strip and the timeline' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM regression' unless ENV['WOODS_MAP_BROWSER']

    result = brush_result
    expect(result.fetch('failures')).to eq([])
    expect(result.fetch('cases')).to eq(4)
  end

  def brush_result
    Dir.mktmpdir('woods-map-brush') do |directory|
      fixture = File.join(directory, 'brush.html')
      File.write(fixture, brush_fixture)
      output, error, status = Open3.capture3(
        ENV.fetch('WOODS_MAP_BROWSER'), '--headless', '--disable-gpu', '--disable-background-networking',
        '--no-first-run', '--virtual-time-budget=30000', "--user-data-dir=#{File.join(directory, 'profile')}",
        '--dump-dom', "file://#{fixture}"
      )
      result = Nokogiri::HTML(output).at_css('#result')
      raise "Brush regression did not produce results: #{error}" unless status.success? && result && !result.text.empty?

      JSON.parse(result.text)
    end
  end

  def brush_pages
    travel_to(Time.utc(2026, 10, 18, 12)) do
      get '/woods/units/job/ApplicationJob/history'
      strip = response.parsed_body.at_css('.strip').to_html
      get '/woods/history', params: { units: %w[job:ApplicationJob mailer:MailingListMailer] }
      plot = response.parsed_body.at_css('.tl-plot').to_html
      [{ name: 'strip', selector: '.strip', html: strip }, { name: 'timeline', selector: '.tl-plot', html: plot }]
    end
  end

  def brush_fixture
    root = File.expand_path('..', __dir__)
    brush = File.read(File.join(root, 'app/javascript/woods_map/controllers/brush_controller.js'))
    data = JSON.generate(pages: brush_pages, brush: brush).gsub('</', '<\\/')
    runner = File.read(File.join(root, 'spec/javascript/brush_runner.js'))
    '<!doctype html><html lang="en"><body><pre id="result"></pre>' \
      "<script>const fixtureData = #{data};\n#{runner}</script></body></html>"
  end
end
