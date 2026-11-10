# frozen_string_literal: true

require_relative 'support/browser_page'
require_relative 'support/trail_index'

RSpec.describe 'Trail walkthrough in Chromium', type: :request do
  include WoodsMap::BrowserPage
  include TrailIndex

  [1440, 960, 640, 390].each do |width|
    it "opens, navigates and reopens its source cards at #{width}px" do
      skip 'Set WOODS_MAP_BROWSER to run the Chromium regression' unless ENV['WOODS_MAP_BROWSER']

      get '/woods/trail', params: { pin: %w[job:NotifySubscribersJob mailer:MailingListMailer], gen: 1 }
      expect(run_page(response.body, runner: walkthrough_runner, width: width))
        .to include('visible' => true, 'hash' => '#walkthrough-2', 'overflow' => false)
    end
  end

  def walkthrough_runner
    <<~JS
      const section = document.querySelector('[aria-labelledby="trail-walkthrough"]')
      const disclosure = section.querySelector('details')
      disclosure.querySelector('summary').click()
      section.querySelector('a[href="#walkthrough-2"]').click()
      disclosure.querySelector('summary').click()
      disclosure.querySelector('summary').click()
      await settle()
      report({ visible: shown(section.querySelector('pre')), hash: location.hash,
        overflow: document.documentElement.scrollWidth > innerWidth })
    JS
  end
end
