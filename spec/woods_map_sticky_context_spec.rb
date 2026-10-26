# frozen_string_literal: true

require_relative 'support/browser_page'
require_relative 'support/hover_card_index'

RSpec.describe 'The sticky context bar in Chromium', type: :request do
  include WoodsMap::BrowserPage
  include HoverCardIndex

  [1440, 960, 640, 390].each do |width|
    it "stays at the top of a deep unit page without moving the source or covering a target at #{width}" do
      skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']

      get '/woods/units/model/Caller'
      result = run_page(response.body, runner: context_runner, width: width, height: 500)
      expect(result).to include('barVisible' => true, 'barOneLine' => true, 'sourceWidth' => 'unchanged',
                                'targetClear' => true, 'topLink' => true, 'ariaHidden' => true)
    end
  end

  def context_runner
    <<~JS
      const bar = () => document.querySelector(".ctx")
      const src = document.querySelector(".cv .src")
      const row = document.querySelector(".cv .row")
      for (let i = 0; i < 300; i++) { const copy = row.cloneNode(true); copy.removeAttribute("id"); row.parentNode.append(copy) }
      const probe = document.createElement("section")
      probe.className = "sec"; probe.id = "probe-target"; probe.textContent = "target"
      document.querySelector(".main").append(probe)
      await settle()
      const before = [src.getBoundingClientRect().width, document.querySelector(".cv").getBoundingClientRect().width]
      window.scrollTo(0, 3000)
      await settle()
      const box = bar() && bar().getBoundingClientRect()
      const after = [src.getBoundingClientRect().width, document.querySelector(".cv").getBoundingClientRect().width]
      location.hash = "#probe-target"
      await settle(100)
      const target = probe.getBoundingClientRect()
      const hidden = bar() && bar().querySelector("[aria-hidden=true]")
      report({
        barVisible: !!box && Math.abs(box.top) < 1 && box.height > 0,
        barOneLine: !!box && box.height < 40,
        sourceWidth: JSON.stringify(before) === JSON.stringify(after) ? "unchanged" : [before, after],
        targetClear: !!box && target.top >= box.bottom - 0.5,
        topLink: !!bar() && !!bar().querySelector("a[href='#']") && !bar().querySelector("[aria-hidden=true] a"),
        ariaHidden: !!hidden
      })
    JS
  end
end
