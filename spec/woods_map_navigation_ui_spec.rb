# frozen_string_literal: true

require_relative 'support/browser_page'

# Navigation and keyboard details in Chromium, on pages the engine renders
# from the fixture index, with the shipped CSS and controllers: the files
# sheet (fetched on first open, folds, filter status, scroll), the bar below
# 960 and 640, the status bar, the trail, the peek, j / k, expand all,
# Shift+Slash, the passage's filter matrix and the timeline at 390.
RSpec.describe 'Navigation in Chromium', type: :request do
  include WoodsMap::BrowserPage

  before do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']

    WoodsMap::FileTree.reset!
  end

  def page_html(path, **params)
    get path, params: params
    expect(response).to have_http_status(:ok)
    response.body
  end

  def tree_fragment
    get '/woods/tree', params: { gen: 1 }
    response.body
  end

  it 'opens the files sheet from the bar at desktop width and loads the tree once, folded, with the current file' do
    html = page_html('/woods/units/model/User')
    runner = sheet_runner
    result = run_page(html, runner: runner, width: 1280, fetches: { '/woods/tree' => tree_fragment })
    expect(result).to include('toggle' => true, 'before' => 0, 'trees' => 1, 'foldedHideChildren' => true,
                              'current' => 'app/models/user.rb', 'currentShown' => true, 'restored' => true,
                              'cleared' => '')
    expect(result['none']).to start_with('No files match')
  end

  it 'keeps search, the primary nav, the status bar and the sheet header usable at 390' do
    html = page_html('/woods/units/model/User')
    runner = phone_runner
    result = run_page(html, runner: runner, width: 390, height: 740, fetches: { '/woods/tree' => tree_fragment })
    expect(result['search']).to include('tap' => true, 'slash' => true)
    expect(result.dig('search', 'width')).to be > 100
    expect(result).to include('clipped' => 0, 'toggle' => [32, 32], 'nav' => 7, 'closeInView' => true,
                              'filterInView' => true, 'focus' => true)
  end

  it 'puts the primary nav in the sheet below 960, where the bar hides it' do
    html = page_html('/woods/units/model/User')
    runner = tablet_runner
    result = run_page(html, runner: runner, width: 900, fetches: { '/woods/tree' => tree_fragment })
    expect(result).to eq('bar' => 0, 'sheet' => %w[Units Landscape Graph ERD Impact History Trail])
  end

  it 'keeps one trail entry per title, never an empty one, and opens help on Shift+Slash' do
    html = page_html('/woods/units/model/User')
    runner = trail_runner
    expect(run_page(html, runner: runner)).to eq('links' => ['UsersController#index'], 'help' => true, 'keys' => 1)
  end

  it 'steps into the results with j from the page and toggles the expand-all label' do
    html = page_html('/woods/impact', focus: 'User', depth: 2)
    runner = rows_runner
    expect(run_page(html, runner: runner)).to eq('entered' => true, 'first' => 'collapse all', 'second' => 'expand all',
                                                 'header' => 'details')
  end

  it 'narrows the filter matrix to the filters on this action' do
    html = page_html('/woods/units/controller/UsersController/passage', action_name: 'show')
    runner = matrix_runner
    result = run_page(html, runner: runner)
    expect(result['shown']).to eq(result['on'])
    expect(result['rail']).to include('#fm')
  end

  it 'draws every timeline dot on screen at 390' do
    html = page_html('/woods/history', units: %w[job:ApplicationJob mailer:MailingListMailer])
    runner = timeline_runner
    expect(run_page(html, runner: runner, width: 390, height: 740)).to eq('dots' => true, 'off' => 0)
  end

  # The page scripts, one per example in order.
  def sheet_runner
    <<~JS
      const toggle = document.querySelector(".bar .menu-toggle")
      const before = document.querySelectorAll("nav.tree").length
      toggle.click()
      await settle(100)
      const rows = [...document.querySelectorAll(".sheet nav.tree [data-tree-target=row]")]
      const folded = rows.filter((row, i) => row.classList.contains("d") && row.getAttribute("aria-expanded") === "false" && rows[i + 1] && +rows[i + 1].dataset.level > +row.dataset.level)
      const current = document.querySelector(".sheet nav.tree [aria-current]")
      const visible = () => rows.filter(shown).length
      const start = visible()
      const filter = document.querySelector(".sheet nav.tree input.filter")
      filter.value = "no-such-path"
      filter.dispatchEvent(new Event("input", { bubbles: true }))
      const none = document.querySelector(".sheet nav.tree [data-tree-target=status]").textContent
      filter.value = ""
      filter.dispatchEvent(new Event("input", { bubbles: true }))
      report({
        toggle: shown(toggle), before, trees: document.querySelectorAll("nav.tree").length,
        foldedHideChildren: folded.length > 0 && folded.every((dir) => rows[rows.indexOf(dir) + 1].hidden),
        current: current?.dataset.path, currentShown: shown(current), none, restored: visible() === start,
        cleared: document.querySelector(".sheet nav.tree [data-tree-target=status]").textContent
      })
    JS
  end

  def phone_runner
    <<~JS
      const input = document.querySelector(".bar-search input.q")
      const search = { width: Math.round(input.getBoundingClientRect().width) }
      document.querySelector(".bar-search > span[aria-hidden]").click()
      search.tap = document.activeElement === input
      document.body.focus(); input.blur()
      const slash = key(document.body, { key: "/", code: "Slash" })
      search.slash = document.activeElement === input && slash.defaultPrevented
      input.blur(); key(document.body, { key: "Escape" })
      const status = [...document.querySelectorAll(".status")].pop()
      const right = status.getBoundingClientRect().right
      const clipped = [...status.children].filter((item) => item.getBoundingClientRect().right > right + 1).length
      const toggle = document.querySelector(".bar .menu-toggle").getBoundingClientRect()
      document.querySelector(".bar .menu-toggle").click()
      await settle(100)
      const close = document.querySelector(".sheet [data-sheet-target=close]").getBoundingClientRect()
      const filter = document.querySelector(".sheet nav.tree input.filter").getBoundingClientRect()
      report({
        search, clipped, toggle: [Math.round(toggle.width), Math.round(toggle.height)],
        nav: [...document.querySelectorAll(".sheet .sheet-nav a")].filter(shown).length,
        closeInView: close.top >= 0 && close.bottom <= innerHeight, filterInView: filter.top >= 0 && filter.bottom <= innerHeight,
        focus: document.activeElement === document.querySelector(".sheet [data-sheet-target=close]")
      })
    JS
  end

  def tablet_runner
    <<~JS
      const bar = [...document.querySelectorAll("header.bar nav a")].filter(shown).length
      document.querySelector(".bar .menu-toggle").click()
      await settle(100)
      report({ bar, sheet: [...document.querySelectorAll(".sheet .sheet-nav a")].filter(shown).map((a) => a.textContent) })
    JS
  end

  def trail_runner
    <<~JS
      sessionStorage.setItem("woods-map.trail", JSON.stringify([
        { title: "User", href: "/woods/units/model/User/schema" }, { title: "", href: "/woods/landscape" },
        { title: "UsersController#index", href: "/woods/units/controller/UsersController/passage" }]))
      const trail = document.querySelector("[data-controller~=trail]")
      trail.removeAttribute("data-controller"); await settle(); trail.setAttribute("data-controller", "trail"); await settle()
      const links = [...document.querySelectorAll("[data-trail-target=list] a")].map((a) => a.textContent)
      key(document.body, { key: "/", code: "Slash", shiftKey: true })
      await settle()
      report({ links, help: document.getElementById("wm-keyboard-help").open, keys: document.querySelectorAll("[data-controller~=keys]").length })
    JS
  end

  def rows_runner
    <<~JS
      key(document.body, { key: "j" })
      const entered = !!document.activeElement.closest("[data-controller~=rows] tbody tr")
      const control = document.querySelector('[data-action~="rows#expandAll"]')
      control.click()
      const first = control.textContent
      control.click()
      report({ entered, first, second: control.textContent,
        header: document.querySelector("#aff")?.closest("section")?.querySelector("th.tg")?.textContent })
    JS
  end

  def matrix_runner
    <<~JS
      const section = document.querySelector("#fm").closest("section")
      const rows = [...section.querySelectorAll("tbody tr")]
      section.querySelector("[data-matrix-target=toggle]").click()
      report({ rows: rows.length, shown: rows.filter(shown).length, on: rows.filter((row) => row.querySelector("td.cur.on")).length,
        rail: [...document.querySelectorAll("nav.rail a")].map((a) => a.getAttribute("href")).filter((href) => href.startsWith("#")) })
    JS
  end

  def timeline_runner
    <<~JS
      const dots = [...document.querySelectorAll(".tl-dot")]
      report({ dots: dots.length > 0, off: dots.filter((dot) => { const r = dot.getBoundingClientRect(); return r.left < 0 || r.right > innerWidth }).length })
    JS
  end
end
