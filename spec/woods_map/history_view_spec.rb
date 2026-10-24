# frozen_string_literal: true

RSpec.describe WoodsMap::HistoryView do
  let(:now) { Time.utc(2026, 10, 18, 12) }
  let(:notify) { 'Notify subscribers when a micropost is created' }

  def view(identifier, type, **options)
    WoodsMap::Repository.open(FIXTURE_INDEX) do |repository|
      yield described_class.new(repository, repository.unit(identifier, type: type), now: now, **options)
    end
  end

  before { WoodsMap::CommitLedger.reset! }

  it 'lists the commits that touched the unit from the commit table, newest first' do
    view('Micropost', 'model') do |history|
      expect(history).to have_attributes(state: :available, paths: ['app/models/micropost.rb'], total: 3)
      expect(history.commits.first).to have_attributes(
        author: 'Leah Armstrong', message: notify,
        description: 'Enqueue the job from after_commit so followers hear within a minute.'
      )
      expect(history.commits.first.generation).to have_attributes(number: 1, baseline: true)
    end
  end

  it 'gives each commit its files, their status, and the units they belong to' do
    view('Micropost', 'model') do |history|
      latest, state = history.commits
      expect(latest.files.map(&:path)).to eq(%w[app/jobs/application_job.rb app/models/micropost.rb])
      expect(latest.units).to eq([%w[ApplicationJob job], %w[Micropost model]])
      expect(state.files.map { |f| [f.path, f.status, f.indexed] })
        .to include(['db/migrate/20260920000000_add_state_to_microposts.rb', 'added', false])
    end
  end

  it 'answers what moves with the unit from CommitTable#co_changes, one row per unit' do
    view('ApplicationJob', 'job') do |history|
      co = history.co_changes.to_h { |c| [[c.identifier, c.type], c.commits] }
      expect(co).to include(%w[Micropost model] => 2, %w[MailingListMailer mailer] => 2)
      expect(co.keys).not_to include(%w[ApplicationJob job])
      expect(history.co_changes.first(2).map(&:identifier)).to contain_exactly('Micropost', 'MailingListMailer')
    end
  end

  it 'narrows to the 30-day range and to one bar of the strip' do
    view('ApplicationJob', 'job', range: '30d') do |history|
      expect([history.days, history.total, history.strip.step]).to eq([30, 2, 1])
    end
    view('ApplicationJob', 'job', week: '2026-10-12') do |history|
      expect(history.commits.map(&:message)).to eq([notify, 'Send subscriber digests from the job'])
    end
  end

  it 'counts people over the window and names its limits' do
    view('Micropost', 'model') do |history|
      expect(history.people.map { |p| [p.name, p.commits] }).to eq([['Leah Armstrong', 2], ['Sam Okafor-Whitfield', 1]])
      expect(history.limits).to include('line counts and hunks are not in the commit table (woods#804)',
                                        'heat is per file, not per line')
    end
  end

  it 'exports a timeline and an XY chart of the strip' do
    view('Micropost', 'model') do |history|
      expect(history.mermaid('timeline')).to start_with("timeline\n  title Micropost history, 365d\n")
        .and include('section 2026-10', '2026-10-15 : ', "#{notify} (Leah Armstrong)")
      expect(history.mermaid('xychart')).to start_with("xychart-beta\n")
        .and include('y-axis "commits per week" 0 --> 1', 'bar [')
    end
  end

  it 'falls back to the five commits of metadata.git without a table and says why' do
    WoodsMap::Repository.open(FIXTURE_INDEX) do |repository|
      allow(repository).to receive_messages(git_commits: nil, commit_table_state: :absent)
      history = described_class.new(repository, repository.unit('Micropost', type: 'model'), now: now)
      expect(history.commits.map(&:message)).to eq(['initial testbed skeleton'])
      expect([history.table?, history.strip, history.co_changes]).to eq([false, nil, []])
      expect(history.limits.first).to eq('1 of 1 commits per unit: this generation has no commit table ' \
                                         '(no readable git history at extraction)')
    end
  end
end
