# frozen_string_literal: true

require_relative 'support/browser_page'

# At container widths of 959px and below the 440px notes lane no longer takes
# the room the wrapped source needs (Chromium, shipped sheets).
RSpec.describe 'Code view space in Chromium', type: :request do
  include WoodsMap::BrowserPage

  before do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']
    get '/woods/units/model/User'
  end

  def measure(width)
    run_page(response.body, width: width, runner: <<~JS)
      const container = document.querySelector(".wm")
      // Pin the queried container too: non-overlay scrollbars can consume viewport width.
      container.style.width = "#{width}px"
      container.dataset.codeWrap = "on"
      await settle(100)
      const box = (selector) => document.querySelector(selector).getBoundingClientRect()
      const lane = document.querySelector(".cv .mg")
      report({ container: container.clientWidth, source: box(".cv .src").width,
               region: box(".cvwrap").width, heat: box(".cv .heat").width,
               lane: getComputedStyle(lane).display === "none" ? 0 : lane.getBoundingClientRect().width })
    JS
  end

  [1440, 960, 640, 390].each do |width|
    it "keeps the activity ink thin within its gutter at #{width}px" do
      report = run_page(response.body, width: width, runner: <<~JS)
        report({ ink: document.querySelector(".cv .heat i").getBoundingClientRect().width })
      JS
      expect(report['ink']).to eq(4)
    end
  end

  it 'keeps highlighted sticky gutters opaque while source scrolls behind them' do
    report = run_page(response.body, width: 390, runner: <<~JS)
      const row = document.querySelector('.cv .row[id]')
      location.hash = row.id
      const region = document.querySelector('.cvwrap')
      region.scrollLeft = region.scrollWidth
      await settle(100)
      report({ scroll: region.scrollLeft, backgrounds: ['.heat', '.ln'].map(selector =>
        getComputedStyle(row.querySelector(selector)).backgroundColor) })
    JS
    expect(report['scroll']).to be_positive
    expect(report['backgrounds']).to all(match(/\Argb\(/))
  end

  it 'gives the wrapped source most of the region where a lane is shown' do
    report = measure(800)
    expect(report['lane']).to be <= 260
    expect(report['source']).to be >= report['region'] * 0.6
  end

  [390, 639].each do |width|
    it "keeps the source filling the region beside the narrow gutters at #{width}" do
      report = measure(width)
      expect(report['container']).to eq(width)
      expect(report['lane']).to eq(0)
      expect(report['heat']).to eq(28)
      expect(report['source']).to eq(report['region'] - 28 - 40)
    end
  end

  it 'retains the tablet notes lane at the exact 640px container boundary' do
    report = measure(640)
    expect(report['container']).to eq(640)
    expect(report['lane']).to eq(240)
    expect(report['heat']).to eq(8)
    expect(report['source']).to eq(report['region'] - 8 - 44 - 240)
  end

  it 'keeps the narrow gutters when an unannotated unit drops the lane at 390' do
    run = run_page(response.body, width: 390, runner: <<~JS)
      document.querySelector(".wm").dataset.codeWrap = "on"
      document.querySelector(".cv").classList.add("nomargin")
      await settle(100)
      const box = (selector) => document.querySelector(selector).getBoundingClientRect()
      report({ source: box(".cv .src").width, region: box(".cvwrap").width, heat: box(".cv .heat").width })
    JS
    expect(run['heat']).to eq(28)
    expect(run['source']).to eq(run['region'] - 28 - 40)
  end
end
