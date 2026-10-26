# frozen_string_literal: true

require_relative 'support/browser_page'
require_relative 'support/trail_index'

RSpec.describe 'The Trail handoff summary in Chromium', type: :request do
  include WoodsMap::BrowserPage
  include TrailIndex

  def report_for(width)
    get '/woods/trail', params: { pin: %w[job:NotifySubscribersJob mailer:MailingListMailer], token: 'never-shared' }
    run_page(response.body, runner: runner, width: width)
  end

  [1440, 390].each do |width|
    context "with a #{width}px window" do
      let(:report) do
        skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']

        report_for(width)
      end
      let(:summary) { report.fetch('summary') }

      it 'copies Markdown built from the notes, with the units as focus links' do
        expect(summary).to start_with('# Trail handoff: ')
        expect(summary).to include('## Conclusion', 'The digest job enqueues once per subscriber.', '## Open question',
                                   'Does a retry enqueue the batch twice?', '## Cited units', 'Read on gen')
        expect(summary.lines.grep(/^- /)).to match(
          [%r{\A- \[NotifySubscribersJob\]\(https?://[^)]*/units/job/NotifySubscribersJob\): Calls the mailer\.\n\z},
           %r{\A- \[MailingListMailer\]\(https?://[^)]*/units/mailer/MailingListMailer\)\n\z}]
        )
        expect(summary).not_to include('never-shared')
      end

      it 'writes the clipboard once and sends, stores and links nothing else' do
        expect(report).to include('writes' => 1, 'fetches' => 0, 'noteInLink' => false, 'storedOnlyNotes' => true,
                                  'announced' => true)
      end
    end
  end

  it 'leaves out an empty conclusion and open question' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']

    get '/woods/trail', params: { pin: %w[job:NotifySubscribersJob] }
    summary = run_page(response.body, runner: <<~JS)['summary']
      let copied = ""
      Object.defineProperty(navigator, "clipboard", { value: { writeText: async (text) => { copied = text } }, configurable: true })
      document.querySelector("[data-action='pinboard#copySummary']").click()
      await settle()
      report({ summary: copied })
    JS
    expect(summary).not_to include('## Conclusion', '## Open question')
    expect(summary).to include('## Cited units')
  end

  def runner
    <<~JS
      let copied = []
      let fetched = 0
      const realFetch = window.fetch
      window.fetch = async (...args) => { fetched += 1; return realFetch(...args) }
      Object.defineProperty(navigator, "clipboard", { value: { writeText: async (text) => { copied.push(text) } }, configurable: true })
      const type = (field, value) => { field.value = value; field.dispatchEvent(new Event("input", { bubbles: true })) }
      type(document.querySelector("textarea[data-pin='conclusion']"), "The digest job enqueues once per subscriber.")
      type(document.querySelector("textarea[data-pin='question']"), "Does a retry enqueue the batch twice?")
      type(document.querySelector("textarea[data-pin='job:NotifySubscribersJob']"), "Calls the mailer.")
      await settle()
      document.querySelector("[data-action='pinboard#copySummary']").click()
      await settle()
      const stored = Object.keys(localStorage).filter((name) => name.startsWith("woods-map:"))
      report({
        summary: copied[0], writes: copied.length, fetches: fetched,
        noteInLink: [...document.querySelectorAll("a[href]")].some((a) => a.href.includes("digest") || a.href.includes("retry")),
        storedOnlyNotes: stored.every((name) => name.startsWith("woods-map:trail-notes:")),
        announced: document.querySelector(".trail-handoff [role='status']").textContent.includes("Copied")
      })
    JS
  end
end
