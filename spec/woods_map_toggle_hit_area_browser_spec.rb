# frozen_string_literal: true

require_relative 'support/browser_page'

RSpec.describe 'The commit detail toggle in Chromium', type: :request do
  include WoodsMap::BrowserPage

  it 'answers a click anywhere in a 24px square around its glyph' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']

    get '/woods/units/job/ApplicationJob/history'
    report = run_page(response.body, runner: corners_runner('table[aria-label="Commits"] .tgl'))
    expect(report).to eq('toggles' => true, 'misses' => [])
  end

  it 'leaves the neighbouring checkbox its own hit area' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']

    get '/woods/guidelines'
    report = run_page(response.body, runner: checkbox_runner)
    expect(report).to eq('pairs' => true, 'stolen' => [])
  end

  def corners_runner(selector)
    <<~JS
      const toggle = document.querySelector(#{selector.to_json})
      toggle.scrollIntoView({ block: "center" })
      await settle()
      const box = toggle.getBoundingClientRect()
      const centre = [box.left + box.width / 2, box.top + box.height / 2]
      const misses = []
      for (const [dx, dy] of [[-11, -11], [11, -11], [-11, 11], [11, 11], [0, 0]]) {
        const hit = document.elementFromPoint(centre[0] + dx, centre[1] + dy)
        if (hit !== toggle) misses.push([dx, dy])
      }
      report({ toggles: !!toggle, misses })
    JS
  end

  def checkbox_runner
    <<~JS
      const pairs = [...document.querySelectorAll(".tgc")].filter((cell) => cell.querySelector("input[type=checkbox]") && cell.querySelector(".tgl"))
      const stolen = []
      pairs.forEach((cell) => {
        const check = cell.querySelector("input[type=checkbox]")
        check.scrollIntoView({ block: "center" })
        const box = check.getBoundingClientRect()
        const hit = document.elementFromPoint(box.left + box.width / 2, box.bottom - 1)
        if (hit !== check) stolen.push(cell.parentElement.parentElement.textContent.trim().slice(0, 20))
      })
      report({ pairs: pairs.length > 0, stolen })
    JS
  end
end
