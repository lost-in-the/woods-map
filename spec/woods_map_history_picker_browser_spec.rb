# frozen_string_literal: true

require_relative 'support/browser_page'

RSpec.describe 'The History unit picker in Chromium', type: :request do
  include WoodsMap::BrowserPage

  [1440, 960, 640, 390].each do |width|
    it "keeps long names, types and counts inside their own labels at #{width}px" do
      skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']

      get '/woods/history'
      report = run_page(response.body, runner: picker_runner, width: width)
      expect(report).to eq('labels' => 3, 'overflowing' => [], 'overlapping' => [])
    end
  end

  def picker_runner
    <<~JS
      const long = ["Admin::Newsletters::CampaignRecipientsSegmentExportsControllerTestWithAVeryLongName", "spec/controllers/admin/newsletters/campaign_recipients_segment_exports_controller_spec.rb", "Short"]
      const labels = [...document.querySelectorAll(".pick-units label.f")].slice(0, 3)
      labels.forEach((label, index) => {
        const name = label.querySelector(".pick-name") || [...label.childNodes].find((node) => node.nodeType === 3 && node.textContent.trim())
        name.textContent = long[index]
      })
      const box = (el) => el.getBoundingClientRect()
      const overflowing = labels.filter((label) => {
        const own = box(label)
        const text = document.createRange()
        text.selectNodeContents(label)
        const used = text.getBoundingClientRect()
        return used.right > own.right + 0.5 || label.scrollWidth > label.clientWidth + 1
      }).map((label) => label.textContent.trim().slice(0, 30))
      const overlapping = []
      labels.forEach((a, i) => labels.slice(i + 1).forEach((b) => {
        const x = box(a), y = box(b)
        if (x.left < y.right - 0.5 && y.left < x.right - 0.5 && x.top < y.bottom - 0.5 && y.top < x.bottom - 0.5) overlapping.push([i, labels.indexOf(b)])
      }))
      report({ labels: labels.length, overflowing, overlapping })
    JS
  end
end
