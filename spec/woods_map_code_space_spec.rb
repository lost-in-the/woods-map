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
      document.querySelector(".wm").dataset.codeWrap = "on"
      await settle(100)
      const box = (selector) => document.querySelector(selector).getBoundingClientRect()
      const lane = document.querySelector(".cv .mg")
      report({ source: box(".cv .src").width, region: box(".cvwrap").width, heat: box(".cv .heat").width,
               lane: getComputedStyle(lane).display === "none" ? 0 : lane.getBoundingClientRect().width })
    JS
  end

  it 'gives the wrapped source most of the region where a lane is shown' do
    report = measure(800)
    expect(report['lane']).to be <= 260
    expect(report['source']).to be >= report['region'] * 0.6
  end

  [390, 640].each do |width|
    it "keeps the source filling the region beside the narrow gutters at #{width}" do
      report = measure(width)
      expect(report['lane']).to eq(0)
      expect(report['heat']).to eq(28)
      expect(report['source']).to eq(report['region'] - 28 - 40)
    end
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
