# frozen_string_literal: true

require_relative 'support/browser_page'
require_relative 'support/hover_card_index'

RSpec.describe 'The peek in Chromium', type: :request do
  include WoodsMap::BrowserPage
  include HoverCardIndex

  it 'stays inside the code region and gives focus back to its reference on Escape' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']

    get '/woods/units/model/Caller'
    html = response.body
    get '/woods/units/model/Domain::Widget/peek'
    peek = response.body
    runner = peek_runner
    expect(run_page(html, runner: runner, width: 1280,
                          fetches: { '/peek' => peek })).to eq('inside' => true, 'back' => true)
  end

  # The page scripts, one per example in order.
  def peek_runner
    <<~JS
      // The margin column of a unit with a lifecycle, which the peek spans too,
      document.querySelector(".cv").classList.remove("nomargin")
      // A line longer than the region, so the source column outgrows it.
      document.querySelector(".cv .src").append(" ".padEnd(300, "x"))
      const link = document.querySelector(".cv .src a[href]")
      link.focus()
      key(link, { key: "p" })
      await settle(100)
      const box = document.querySelector(".cv .peek").getBoundingClientRect()
      const region = document.querySelector(".cvwrap").getBoundingClientRect()
      key(document.activeElement, { key: "Escape" })
      report({ inside: box.right <= region.right + 0.5 && box.left >= region.left, back: document.activeElement === link })
    JS
  end
end
