# frozen_string_literal: true

require_relative 'support/browser_page'
require_relative 'support/range_report_fixture'

RSpec.describe 'Full identities of truncated table cells in Chromium', type: :request do
  include WoodsMap::BrowserPage
  include RangeReportFixture

  before { stub_range_report }

  [1440, 960, 640, 390].each do |width|
    it "shows the full name, type and mechanism on focus, with no extra tab stop on a link, at #{width}" do
      skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']

      get '/woods/impact', params: { from: 'gen:1', lens: 'changed' }
      expect(run_page(response.body, runner: tip_runner, width: width + 15, height: 700)).to eq(
        'linkTip' => true, 'linkCellTabStop' => false, 'plainTabStop' => true, 'plainTip' => true,
        'shortQuiet' => true
      )
    end
  end

  def tip_runner
    <<~JS
      const rows = [...document.querySelectorAll('table[aria-label="Affected units"] tbody tr:not(.sub)')]
      const [linked, plain] = rows.map((row) => row.querySelector("td.id"))
      const long = "VeryLong::".repeat(30)
      linked.querySelector("a").textContent = long + "Linked"
      plain.textContent = long + "Plain"
      const tipText = () => document.querySelector(".tip")?.textContent
      const focus = (el) => { el.focus(); el.dispatchEvent(new FocusEvent("focusin", { bubbles: true })) }
      await settle(100)
      focus(linked.querySelector("a"))
      const linkTip = tipText()
      key(document.activeElement, { key: "Escape" })
      focus(plain)
      const plainTip = tipText()
      key(document.activeElement, { key: "Escape" })
      plain.textContent = "Short"
      await settle(100)
      focus(plain)
      report({
        linkTip: !!linkTip && linkTip.includes("UsersController") && linkTip.includes("controller") && linkTip.includes("code_reference"),
        linkCellTabStop: linked.hasAttribute("tabindex"),
        plainTabStop: plain.getAttribute("tabindex") === "0",
        plainTip: !!plainTip && plainTip.includes("Gone") && plainTip.includes("service"),
        shortQuiet: !tipText()
      })
    JS
  end
end
