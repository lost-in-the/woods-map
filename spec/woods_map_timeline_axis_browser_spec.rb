# frozen_string_literal: true

require_relative 'support/browser_page'

RSpec.describe 'History timeline date ink in Chromium', type: :request do
  include WoodsMap::BrowserPage

  [1440, 960, 640, 390].each do |width|
    it "keeps measured date labels apart at #{width}px" do
      skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']

      get '/woods/history', params: { units: ['job:ApplicationJob'], range: '365d' }
      result = run_page(response.body, runner: axis_runner, width: width)
      expect(result.fetch('count')).to be >= 2
      expect(result.fetch('overlaps')).to eq([])
    end
  end

  it 'selects a meaningful span across distinct commits in the synthetic fixture' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']

    get '/woods/history', params: { units: ['job:ApplicationJob'], range: '365d' }
    result = run_page(response.body, runner: span_runner)
    expect(result.fetch('count')).to be >= 3
    expect(result.fetch('steps')).to be > 1
    get result.fetch('destination')
    expect(html_response_document.css('.tl-svg a').size).to eq(result.fetch('count'))
    expect(html_response_document.at_css('#lanes').text).to include('from')
  end

  def span_runner
    <<~JS
      const plot = document.querySelector('.tl-plot')
      const dots = [...plot.querySelectorAll('a[data-index]')]
      const controller = application.getControllerForElementAndIdentifier(plot, 'brush')
      let destination = null
      controller.navigate = url => { destination = url }
      const first = dots[0], last = dots[dots.length - 1]
      first.focus()
      const steps = Number(last.dataset.index) - Number(first.dataset.index)
      for (let i = 0; i < steps; i++) key(first, {key: 'ArrowRight', shiftKey: true})
      key(first, {key: 'Enter'})
      report({count: dots.length, steps, destination})
    JS
  end

  def axis_runner
    <<~JS
      await settle(200)
      const labels = [...document.querySelectorAll('.tl-plot .strip-axis text')].filter(shown)
      const overlaps = []
      labels.forEach((a, i) => labels.slice(i + 1).forEach(b => {
        const x = a.getBoundingClientRect(), y = b.getBoundingClientRect()
        if (x.right > y.left && y.right > x.left) overlaps.push([a.textContent, b.textContent])
      }))
      report({count: labels.length, overlaps})
    JS
  end
end
