# frozen_string_literal: true

require_relative 'support/browser_page'
require_relative 'support/trail_index'

RSpec.describe 'The Trail pin note in Chromium', type: :request do
  include WoodsMap::BrowserPage
  include TrailIndex

  [1440, 960, 640, 390].each do |width|
    it "shows a multi-paragraph note whole while it is edited at #{width}px" do
      skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']

      get '/woods/trail', params: { pin: %w[job:NotifySubscribersJob mailer:MailingListMailer] }
      report = run_page(response.body, runner: note_runner, width: width)
      expect(report).to eq('hidden' => 0, 'kept' => true)
    end
  end

  def note_runner
    <<~JS
      const note = document.querySelector("textarea.trail-note")
      note.value = ["Conclusion: the digest job enqueues the mailer once per subscriber.", "", "Evidence: NotifySubscribersJob#perform calls MailingListMailer.digest for each batch.", "", "Open question: does a retry enqueue the batch a second time?"].join("\\n")
      note.dispatchEvent(new Event("input", { bubbles: true }))
      note.focus()
      await settle()
      report({ hidden: Math.max(0, note.scrollHeight - note.clientHeight - 1), kept: note.value.includes("Open question") })
    JS
  end
end
