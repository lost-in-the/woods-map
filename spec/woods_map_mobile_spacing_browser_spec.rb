# frozen_string_literal: true

require_relative 'support/browser_page'

RSpec.describe 'Nested mobile content spacing in Chromium', type: :request do
  include WoodsMap::BrowserPage

  before do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']
  end

  [390, 640, 960, 1440].each do |width|
    ['/woods/erd', '/woods/impact?focus=User', '/woods/units/model/User'].each do |path|
      it "keeps content insets bounded on #{path} at #{width}px" do
        get path
        report = run_page(response.body, width: width, runner: spacing_runner(width))
        inset = width < 960 ? 8 : 21
        expect(report.values_at('container', 'outer')).to eq([width, inset])
        expect(report.fetch('sections')).to all(eq(inset))
        expect(report.fetch('sections')).not_to be_empty
        expect(report.fetch('contained')).to be(true)
      end
    end
  end

  # @param width [Integer] exact queried container width, independent of scrollbar allocation
  # @return [String] measure both nested insets on rendered pages, including the section edge
  def spacing_runner(width)
    <<~JS
      const container = document.querySelector('.wm')
      container.style.width = "#{width}px"
      await settle()
      const body = document.querySelector('.body')
      report({
        container: container.clientWidth,
        outer: parseFloat(getComputedStyle(body).marginLeft),
        sections: [...body.querySelectorAll('.main .sec')].map(e => parseFloat(getComputedStyle(e).marginLeft)),
        contained: document.documentElement.scrollWidth <= innerWidth
      })
    JS
  end
end
