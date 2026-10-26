# frozen_string_literal: true

require_relative 'support/browser_page'
require_relative 'support/trail_index'

# The Trail's graph of two pinned units, drawn by the shipped graph controller and the vendored
# Cytoscape in Chromium: both units are inside the canvas on the first view and after "fit".
RSpec.describe 'The pinned graph in Chromium', type: :request do
  include WoodsMap::BrowserPage
  include TrailIndex

  let(:pins) { %w[job:NotifySubscribersJob mailer:MailingListMailer] }

  [1440, 960, 640, 390].each do |width|
    it "shows both units inside the canvas at #{width}px, drawn and after fit" do
      skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']

      report = pinned_report(width)
      canvas = report.fetch('canvas')
      expect(canvas.fetch('width')).to be > 300
      %w[drawn fitted].each do |moment|
        report.fetch(moment).each do |box|
          expect(box.values_at('x1', 'y1')).to all(be >= 0)
          expect(box.fetch('x2')).to be <= canvas.fetch('width')
          expect(box.fetch('y2')).to be <= canvas.fetch('height')
        end
      end
    end
  end

  def pinned_report(width)
    get '/woods/trail', params: { pin: pins }
    html = response.body
    get '/woods/trail/graph', params: { pin: pins }
    run_page(html, runner: pinned_runner, width: width, fetches: { 'trail/graph' => response.body })
  end

  def pinned_runner
    <<~JS
      await settle(1500)
      const graph = application.getControllerForElementAndIdentifier(document.querySelector("[data-controller~=graph]"), "graph")
      const canvas = document.querySelector(".gcanvas").getBoundingClientRect()
      const boxes = () => graph.cy.nodes().map((node) => {
        const box = node.renderedBoundingBox({ includeLabels: true })
        return { x1: box.x1, y1: box.y1, x2: box.x2, y2: box.y2 }
      })
      const drawn = boxes()
      graph.fit()
      report({ canvas: { width: canvas.width, height: canvas.height }, drawn, fitted: boxes() })
    JS
  end
end
