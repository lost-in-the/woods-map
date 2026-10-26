# frozen_string_literal: true

require_relative 'support/browser_page'

RSpec.describe 'The reading trail in Chromium', type: :request do
  include WoodsMap::BrowserPage

  it 'returns to a page with the query it was read with, and still draws a path-only entry' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM regression' unless ENV['WOODS_MAP_BROWSER']

    get '/woods/units/model/User', params: { lens: 'written', token: 'secret' }
    first = response.body
    get '/woods/units/model/Micropost'
    second = Nokogiri::HTML(response.body).at_css('main').inner_html
    expect(run_page(first, runner: trail_runner(second), width: 1280)).to eq(
      'stored' => '/woods/units/model/User?lens=written',
      'href' => '/woods/units/model/User?lens=written',
      'legacy' => '/woods/units/model/Legacy'
    )
  end

  def trail_runner(next_main)
    <<~JS
      const stored = JSON.parse(sessionStorage.getItem("woods-map.trail"))[0].href
      sessionStorage.setItem("woods-map.trail", JSON.stringify([...JSON.parse(sessionStorage.getItem("woods-map.trail")), { title: "Legacy", href: "/woods/units/model/Legacy" }]))
      document.querySelector("main").innerHTML = #{next_main.to_json}
      await settle(100)
      const links = [...document.querySelectorAll("[data-trail-target=list] a")]
      report({ stored, href: links[0].getAttribute("href"), legacy: links.map((a) => a.getAttribute("href")).find((h) => h.endsWith("Legacy")) })
    JS
  end
end
