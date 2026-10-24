# frozen_string_literal: true

require_relative '../support/history_index'

RSpec.describe 'History', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  before do
    WoodsMap::CommitLedger.reset!
    travel_to Time.utc(2026, 10, 18, 12)
  end

  def doc
    html_response_document
  end

  describe 'the History tab' do
    it 'draws the commit strip with a link per bar that has commits' do
      get '/woods/units/job/ApplicationJob/history'
      strip = doc.at_css('svg.strip-svg')
      expect(strip['aria-label']).to eq('3 commits touching application_job.rb in 365 days, 2 in the last 4 weeks')
      expect(strip.css('rect.bar.recent:not(.zero)').size).to eq(1)
      expect(strip.css('a').pluck('href')).to include('/woods/units/job/ApplicationJob/history?week=2026-10-12#commits')
    end

    it 'lists the commit table rows with their detail blocks' do
      get '/woods/units/job/ApplicationJob/history'
      row = doc.css('table[aria-label="Commits"] tbody tr:not(.sub)').first
      expect(row.text).to include('Notify subscribers when a micropost is created', '2 files, 2 units', '≤ 1')
      detail = doc.css('table[aria-label="Commits"] tbody tr.sub').map(&:text).join
      expect(detail).to include('The job batches followers', 'app/views/mailing_list_mailer/new_post.html.erb',
                                'line counts and hunks are not in the commit table (woods#804)', 'Micropost')
    end

    it 'answers what moves with the unit in the rail and links the timeline of that set' do
      get '/woods/units/job/ApplicationJob/history'
      rail = doc.at_css('nav.rail').text
      expect(rail).to include('moves with, co-change', 'Micropost', 'MailingListMailer', 'Sam Okafor-Whitfield')
      link = doc.css('a').find { |a| a.text == 'timeline with what moves with it' }
      expect(CGI.unescape(link['href'])).to include('units[]=job:ApplicationJob', 'units[]=model:Micropost')
    end

    it 'filters to a bar and to the 30-day range, and lists every commit on request' do
      get '/woods/units/job/ApplicationJob/history', params: { week: '2026-10-12' }
      expect(doc.at_css('#commits').text).to include('2 in the week of 2026-10-12', 'all weeks')
      get '/woods/units/job/ApplicationJob/history', params: { range: '30d' }
      expect(doc.at_css('.seg a[aria-current="true"]').text).to eq('30d')
      expect(doc.at_css('svg.strip-svg')['aria-label']).to include('in 30 days')
      get '/woods/units/model/User/history', params: { all: '1' }
      expect(doc.at_css('#commits').text).to include('2 in 365d')
    end

    it 'serves the timeline and the XY chart as Mermaid text' do
      get '/woods/units/model/Micropost/history.mmd'
      expect(response.media_type).to eq('text/plain')
      expect(response.body).to start_with("timeline\n  title Micropost history, 365d\n")
      get '/woods/units/model/Micropost/history.mmd', params: { view: 'xychart', range: '30d' }
      expect(response.body).to start_with("xychart-beta\n").and include('commits per day')
      expect(response.headers['X-Woods-Generation']).to eq('1')
    end

    it 'keeps the five-commit fallback, and its limit, without a commit table' do
      allow_any_instance_of(WoodsMap::Repository).to receive(:git_commits).and_return(nil) # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(WoodsMap::Repository).to receive(:commit_table_state).and_return(:absent) # rubocop:disable RSpec/AnyInstance
      get '/woods/units/model/User/history'
      expect(response.body).to include('initial testbed skeleton', 'this generation has no commit table')
      expect(doc.at_css('svg.strip-svg')).to be_nil
      get '/woods/units/model/User/history.mmd'
      expect(response.body).to start_with('timeline')
    end
  end

  describe 'generations' do
    let(:root) { WoodsMap::HistoryIndex.build(generations: 3) }

    before { WoodsMap.configuration.index_dir = root }
    after { FileUtils.rm_rf(root) }

    it 'names the generation that carried each commit and offers a diff between retained generations' do
      get '/woods/units/job/ApplicationJob/history'
      expect(doc.css('nav.rail li').map(&:text).join(' ')).to include('3', '2')
      gens = doc.css('table[aria-label="Commits"] tbody tr:not(.sub)').map { |tr| tr.css('td').last.text.strip }
      expect(gens).to eq(['3', '2', '≤ 1'])
      primary = doc.at_css('.ident a.btn.primary')
      expect(primary.text).to eq('Diff gen 2 → 3')
      expect(doc.at_css('select#diff-from').css('option').map(&:text)).to eq(['gen 1', 'gen 2', 'gen 3'])
    end

    it "renders the unit's record from Woods' report for two generations" do
      record = { 'identifier' => 'ApplicationJob', 'type' => 'job', 'status' => 'modified', 'facets' => ['source'],
                 'categories' => ['behaviour'], 'metadata_keys' => [],
                 'diff_stats' => { 'source_before' => { 'lines' => 3 }, 'source_after' => { 'lines' => 5 } } }
      range = instance_double(WoodsMap::ImpactRange, state: :available, data: { 'changed' => [record] }, message: nil)
      allow(WoodsMap::ImpactRange).to receive(:new).and_return(range)
      get '/woods/units/job/ApplicationJob/history', params: { from: '1', to: '3' }
      section = doc.at_css('section#diff').text
      expect(section).to include('gen 1 → 3', 'modified', 'source', '3 lines → 5 lines', 'woods#802')
      expect(doc.at_css('section#diff a.goto')['href']).to eq('/woods/impact?from=gen%3A1&to=gen%3A3')
    end
  end

  describe '/woods/history' do
    it 'offers the most-changed units when nothing is selected' do
      get '/woods/history'
      expect(response).to have_http_status(:ok)
      values = doc.css('input[name="units[]"]').pluck('value')
      expect(values).to include('job:ApplicationJob', 'model:Micropost')
      expect(doc.at_css('.bar nav, nav').text).to include('History')
    end

    it 'draws one lane per unit and the pair that changed together (scenario 2, step 3)' do
      get '/woods/history', params: { units: %w[job:ApplicationJob mailer:MailingListMailer] }
      expect(doc.css('.tl-names li').map { |li| li.at_css('a').text }).to eq(%w[ApplicationJob MailingListMailer])
      expect(doc.css('svg.tl-svg line.tl-pair').size).to eq(2)
      pairs = doc.at_css('table[aria-label="Changed together"] tbody').text
      expect(pairs).to include('ApplicationJob', 'MailingListMailer', 'Sam Okafor-Whitfield')
      commits = doc.at_css('table[aria-label="Commits"]').text
      expect(commits).to include('Send subscriber digests from the job')
    end

    it 'serves the timeline as Mermaid text and asks for units without them' do
      get '/woods/history.mmd', params: { units: %w[job:ApplicationJob mailer:MailingListMailer] }
      expect(response.body).to start_with("timeline\n  title ApplicationJob, MailingListMailer, 365d\n")
      get '/woods/history.mmd'
      expect(response).to have_http_status(:bad_request)
    end
  end

  it 'colours the code view gutter per file from the commit table' do
    get '/woods/units/model/Micropost'
    heat = doc.at_css('.cv .heat i')
    expect(heat['class']).to eq('h2')
    expect(heat['title']).to start_with('active: 3 commits in the commit table, app/models/micropost.rb')
  end
end
