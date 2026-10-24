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
                                '+3 −1', 'Micropost')
    end

    it "shows each file's line counts and links the latest commit's hunks into the Code view" do
      skip 'needs a Woods whose commit table reader has line_stats? (woods#804)' unless WoodsLineStats.supported?
      get '/woods/units/job/ApplicationJob/history'
      sub = doc.css('table[aria-label="Commits"] tbody tr.sub').first
      expect(sub.text).to include('app/jobs/application_job.rb +2 −1', 'L3–4')
      expect(sub.css('a').pluck('href')).to include('/woods/units/job/ApplicationJob#L3')
      older = doc.css('table[aria-label="Commits"] tbody tr.sub')[1]
      expect(older.css('a').pluck('href')).not_to include('/woods/units/job/ApplicationJob#L3')
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
    let(:source_diff) do
      lines = [{ 'op' => ' ', 'before' => 3, 'after' => 3, 'text' => 'end' },
               { 'op' => '+', 'before' => nil, 'after' => 4, 'text' => '  queue_as :default' },
               { 'op' => '+', 'before' => nil, 'after' => 5, 'text' => '  retry_on' }]
      instance_double(WoodsMap::SourceDiff, state: :available, status: 'modified',
                                            categories: ['behaviour'],
                                            hunks: [{ 'before' => [3, 1], 'after' => [3, 3], 'lines' => lines }],
                                            changes: { 'added_lines' => 2, 'removed_lines' => 0,
                                                       'coverage' => 'complete' })
    end

    before { WoodsMap.configuration.index_dir = root }
    after { FileUtils.rm_rf(root) }

    it 'names the generation that carried each commit and offers a diff between retained generations' do
      allow(WoodsMap::SourceDiff).to receive(:backend).and_return(nil)
      get '/woods/units/job/ApplicationJob/history'
      expect(doc.css('nav.rail li').map(&:text).join(' ')).to include('3', '2')
      gens = doc.css('table[aria-label="Commits"] tbody tr:not(.sub)').map { |tr| tr.css('td').last.text.strip }
      expect(gens).to eq(['3', '2', '≤ 1'])
      primary = doc.at_css('.ident a.btn.primary')
      expect(primary.text).to eq('Diff gen 2 → 3')
      expect(doc.at_css('select#diff-from').css('option').map(&:text)).to eq(['gen 1', 'gen 2', 'gen 3'])
    end

    it "shows the facets Woods recorded moving at each commit's generation" do
      allow(WoodsMap::SourceDiff).to receive(:backend).and_return(Class.new)
      moved = { 2 => ['modified', %w[behaviour edges]], 3 => ['unchanged', []] }
      allow(WoodsMap::SourceDiff).to receive(:new) do |_dir, to:, **|
        status, categories = moved.fetch(to)
        instance_double(WoodsMap::SourceDiff, state: :available, status: status, categories: categories)
      end
      get '/woods/units/job/ApplicationJob/history'
      table = doc.at_css('table[aria-label="Commits"]')
      expect(table.css('thead th').map(&:text)).to include('facets moved')
      cells = table.css('tbody tr:not(.sub)').map { |tr| tr.css('td').last.text.strip }
      expect(cells).to eq(['unchanged', 'behaviour, edges', 'none'])
      expect(WoodsMap::SourceDiff).to have_received(:new).with(anything, hash_including(from: 1, to: 2))
    end

    it 'marks the commits that arrived after the ?since= generation, on the tab and the timeline' do
      data = { 'schema_version' => 1, 'parameters' => {}, 'coverage' => {}, 'changed' => [], 'affected' => [],
               'flows' => [], 'unknowns' => [],
               'range' => { 'from' => { 'generation' => 2 }, 'to' => { 'generation' => 3 } } }
      range = instance_double(WoodsMap::ImpactRange, state: :available, data: data, message: nil)
      allow(WoodsMap::ImpactRange).to receive(:new).and_return(range)
      get '/woods/units/job/ApplicationJob/history', params: { since: 'gen:2' }
      rows = doc.css('table[aria-label="Commits"] tbody tr:not(.sub)')
      expect(rows.map { |tr| tr['class'].to_s.include?('chg') }).to eq([true, false, false])
      expect(rows.first.at_css('.sr-only').text).to include('arrived after gen 2')
      get '/woods/history', params: { units: %w[job:ApplicationJob], since: 'gen:2' }
      expect(doc.css('table[aria-label="Commits"] tbody tr.chg').size).to eq(1)
    end

    it 'groups the strip by generation, each bar linking to the commits it first carried' do
      get '/woods/units/job/ApplicationJob/history', params: { by: 'generation' }
      bars = doc.css('svg.strip-svg a').map { |a| [a['aria-label'], a['href']] }
      expect(bars.map(&:first)).to eq(['1 commit already in gen 1, the oldest retained table',
                                       '1 commit first carried by gen 2', '1 commit first carried by gen 3'])
      expect(bars.last.last).to include('by=generation', 'gen=3')
      expect(doc.at_css('.seg[aria-label="Group commits by"] a[aria-current="true"]').text).to eq('generation')
    end

    it 'lists only the commits one generation first carried' do
      get '/woods/units/job/ApplicationJob/history', params: { by: 'generation', gen: '2' }
      expect(doc.at_css('h2#commits-title').text).to include('1 first carried by gen 2')
      expect(doc.css('table[aria-label="Commits"] tbody tr:not(.sub)').size).to eq(1)
      expect(doc.at_css('#commits .tools a').text).to eq('all generations')
    end

    it "renders the unit's record from Woods' report for two generations" do
      record = { 'identifier' => 'ApplicationJob', 'type' => 'job', 'status' => 'modified', 'facets' => ['source'],
                 'categories' => ['behaviour'], 'metadata_keys' => [],
                 'diff_stats' => { 'source_before' => { 'lines' => 3 }, 'source_after' => { 'lines' => 5 } } }
      range = instance_double(WoodsMap::ImpactRange, state: :available, data: { 'changed' => [record] }, message: nil)
      allow(WoodsMap::ImpactRange).to receive(:new).and_return(range)
      allow(WoodsMap::SourceDiff).to receive(:new).and_return(source_diff)
      get '/woods/units/job/ApplicationJob/history', params: { from: '1', to: '3' }
      section = doc.at_css('section#diff').text
      expect(section).to include('gen 1 → 3', 'modified', 'source', '3 lines → 5 lines', '2 lines added, 0 removed')
      expect(doc.css('section#diff .difft .dl.add').map(&:text)).to eq(['4+ added  queue_as :default',
                                                                        '5+ added  retry_on'])
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
