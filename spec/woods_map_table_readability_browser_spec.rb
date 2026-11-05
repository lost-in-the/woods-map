# frozen_string_literal: true

require_relative 'support/browser_page'

RSpec.describe 'ERD and Impact table readability in Chromium', type: :request do
  include WoodsMap::BrowserPage

  before do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']
  end

  [1440, 960, 640, 390].each do |width|
    it "keeps ERD headers separated and full identifiers scrollable at #{width}px" do
      get '/woods/erd'
      report = run_page(response.body, width: width, runner: erd_runner)
      expect(report).to eq('overlap' => [], 'fullValues' => true, 'contained' => true,
                           'uniqueLabels' => true, 'cue' => true)
    end

    it "reserves readable notes and nonoverlapping headers in Impact at #{width}px" do
      get '/woods/impact', params: { focus: 'User', depth: 2 }
      report = run_page(response.body, width: width, runner: impact_runner)
      expect(report).to eq('overlap' => [], 'notesFit' => true, 'contained' => true)
    end
  end

  # @return [String] measure header ink against each cell's content box
  def table_measurements
    <<~JS
      const overlap = [...document.querySelectorAll("table th")].filter((cell) => {
        if (cell.colSpan > 1 || cell.classList.contains("tg")) return false
        const range = document.createRange()
        range.selectNodeContents(cell)
        const ink = range.getBoundingClientRect(), box = cell.getBoundingClientRect()
        return ink.right > box.right - parseFloat(getComputedStyle(cell).paddingRight) + 1
      }).map((cell) => cell.textContent.trim())
      const contained = document.documentElement.scrollWidth <= document.documentElement.clientWidth
    JS
  end

  # @return [String] long published identities stay complete in focusable scroll regions
  def erd_runner
    <<~JS
      #{table_measurements}
      const table = document.querySelector('table[aria-label="Tables in this chunk"]')
      const cells = [table.querySelector('td[data-h="table"]'), table.querySelector('td[data-h="model"]')]
      let cue = true
      const fullValues = cells.every((cell) => {
        const value = cell.querySelector('[role="region"]')
        if (!value) return false
        const link = value.querySelector('a')
        link.textContent = "PublishedIdentifierWithoutBreaks".repeat(8)
        application.getControllerForElementAndIdentifier(value, "cliff").update()
        const hint = value.nextElementSibling
        cue = cue && !!hint && getComputedStyle(hint).display !== "none" && hint.textContent.includes("Scroll value")
        value.focus()
        value.scrollLeft = value.scrollWidth
        application.getControllerForElementAndIdentifier(value, "cliff").update()
        cue = cue && getComputedStyle(hint).display !== "none"
        return value.getAttribute("aria-label") && value === document.activeElement && value.scrollLeft > 0 &&
          value.scrollWidth > value.clientWidth && link.textContent === "PublishedIdentifierWithoutBreaks".repeat(8)
      })
      const fitting = cells[0].querySelector('[role="region"]')
      fitting.querySelector('a').textContent = "x"
      fitting.scrollLeft = 0
      application.getControllerForElementAndIdentifier(fitting, "cliff").update()
      cue = cue && getComputedStyle(fitting.nextElementSibling).display === "none" && !fitting.hasAttribute("tabindex")
      const labels = [...table.querySelectorAll('[role="region"]')].map((el) => el.getAttribute("aria-label"))
      report({ overlap, fullValues, contained, cue, uniqueLabels: new Set(labels).size === labels.length })
    JS
  end

  # @return [String] the Notes column fits a whole word and a compact multi-line sentence
  def impact_runner
    <<~JS
      #{table_measurements}
      const notes = document.querySelector('table[aria-label="Focus units"] td[data-h="notes"]')
      const style = getComputedStyle(notes)
      const canvas = document.createElement("canvas"), context = canvas.getContext("2d")
      context.font = style.font
      const available = notes.clientWidth - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight)
      const longest = notes.textContent.trim().split(/\\s+/).reduce((a, b) => a.length > b.length ? a : b)
      const notesFit = available >= context.measureText(longest).width &&
        notes.scrollWidth <= notes.clientWidth + 1 && notes.clientHeight <= parseFloat(style.lineHeight) * 4 +
          parseFloat(style.paddingTop) + parseFloat(style.paddingBottom)
      report({ overlap, notesFit, contained })
    JS
  end
end
