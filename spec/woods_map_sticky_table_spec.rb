# frozen_string_literal: true

require_relative 'support/browser_page'
require_relative 'support/range_report_fixture'

RSpec.describe 'Sticky table headers in Chromium', type: :request do
  include WoodsMap::BrowserPage
  include RangeReportFixture

  # The layout width the breakpoints see is the window less the classic scrollbar headless Chromium draws.
  SCROLLBAR = 15

  before { stub_range_report }

  { 1440 => true, 960 => true, 640 => true, 390 => false }.each do |width, sticks|
    it "#{sticks ? 'keeps' : 'does not keep'} the header and the generation pair in view of a scrolled table at #{width}" do
      skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']

      get '/woods/impact', params: { from: 'gen:1', lens: 'changed' }
      result = run_page(response.body, runner: table_runner, width: width + SCROLLBAR, height: 700)
      expect(result).to include('headerStays' => sticks, 'pairInHeader' => true, 'firstColumnStays' => true,
                                'keyboardRegion' => true)
    end
  end

  def table_runner
    <<~JS
      const wrap = document.querySelector('.tblwrap:has(table[aria-label="Changed units"])')
      const table = wrap.querySelector("table")
      const body = table.querySelector("tbody")
      const first = body.querySelector("tr")
      for (let i = 0; i < 60; i++) body.append(first.cloneNode(true))
      table.classList.add("sticky")
      await settle(300)
      wrap.scrollTop = wrap.scrollHeight
      wrap.dispatchEvent(new Event("scroll"))
      await settle(100)
      const head = table.querySelector("thead").getBoundingClientRect()
      const box = wrap.getBoundingClientRect()
      const labels = [...table.querySelectorAll("thead th")].map((th) => th.textContent.replace(/\\s+/g, " "))
      const cell = body.querySelector("tr:last-child td:first-child")
      const corner = table.querySelector("thead tr:last-child th:first-child")
      const start = [cell.getBoundingClientRect().left, corner.getBoundingClientRect().left]
      wrap.scrollLeft = wrap.scrollWidth
      await settle(100)
      const stays = wrap.scrollLeft === 0 ||
        (Math.abs(cell.getBoundingClientRect().left - start[0]) < 1 && Math.abs(corner.getBoundingClientRect().left - start[1]) < 1)
      report({
        headerStays: Math.abs(head.top - box.top) < 2 && wrap.scrollTop > 0,
        pairInHeader: labels.some((text) => text.includes("gen 1 → gen 1")),
        firstColumnStays: stays,
        keyboardRegion: wrap.getAttribute("tabindex") === "0"
      })
    JS
  end
end
