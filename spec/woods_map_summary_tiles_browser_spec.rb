# frozen_string_literal: true

require_relative 'support/browser_page'

RSpec.describe 'The unit summary tiles in Chromium', type: :request do
  include WoodsMap::BrowserPage

  [1440, 960, 640, 390].each do |width|
    it "breaks a namespaced name only at its namespace and shares the row among its tiles at #{width}px" do
      skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']

      get '/woods/units/job/ApplicationJob/history'
      report = run_page(response.body, runner: tiles_runner, width: width)
      expect(report).to eq('tiles' => true, 'midWord' => [], 'gap' => 0)
    end
  end

  def tiles_runner
    <<~JS
      const facts = document.querySelector(".frame-facts .facts")
      const tiles = [...facts.children]
      const value = facts.querySelector("dd")
      value.innerHTML = "<a href='#'>Newsletter::<wbr>CampaignsController</a> and <a href='#'>Admin::<wbr>Newsletters::<wbr>CampaignRecipientsController</a>"
      await settle()
      const midWord = []
      value.querySelectorAll("a").forEach((link) => {
        const text = link.firstChild
        let top = null
        for (let i = 0; i < link.textContent.length; i++) {
          const node = [...link.childNodes].filter((n) => n.nodeType === 3)
          const range = document.createRange()
          let offset = i, target = null
          for (const n of node) { if (offset < n.length) { target = n; break } offset -= n.length }
          if (!target) continue
          range.setStart(target, offset); range.setEnd(target, offset + 1)
          const y = Math.round(range.getBoundingClientRect().top)
          if (top !== null && y > top + 4 && !/[:]/.test(link.textContent[i - 1])) midWord.push(link.textContent.slice(Math.max(0, i - 4), i + 4))
          top = y
        }
      })
      const unused = facts.getBoundingClientRect().width - tiles.reduce((sum, tile) => sum + tile.getBoundingClientRect().width, 0)
      const stacked = tiles.every((tile) => Math.abs(tile.getBoundingClientRect().left - tiles[0].getBoundingClientRect().left) < 2)
      report({ tiles: tiles.length > 0, midWord, gap: stacked || unused < 3 ? 0 : Math.round(unused) })
    JS
  end
end
