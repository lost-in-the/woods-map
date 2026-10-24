# frozen_string_literal: true

RSpec.describe WoodsMap::HistoryTimeline do
  let(:now) { Time.utc(2026, 10, 18, 12) }

  def timeline(selection, **options)
    WoodsMap::Repository.open(FIXTURE_INDEX) do |repository|
      yield described_class.new(repository, selection, now: now, **options)
    end
  end

  # Design-study scenario 2, step 3: the job and the mailer were changed
  # together in one commit days ago, by a teammate, in a "digest" change.
  it 'answers which commits changed the job and the mailer together from the commit table' do
    timeline(%w[job:ApplicationJob mailer:MailingListMailer]) do |t|
      pair = t.pairs.first
      expect([pair.left.identifier, pair.right.identifier]).to eq(%w[ApplicationJob MailingListMailer])
      together = t.events.find { |e| pair.shas.include?(e.sha) }
      expect(together).to have_attributes(author: 'Sam Okafor-Whitfield', lanes: [0, 1],
                                          message: 'Send subscriber digests from the job')
      expect((now - Time.iso8601(together.date)).div(86_400)).to eq(5)
    end
  end

  it 'resolves typed and bare identifiers and keeps unknown ones aside' do
    timeline(%w[Micropost job:ApplicationJob model:Nope]) do |t|
      expect(t.lanes.map { |l| [l.identifier, l.type] }).to eq([%w[Micropost model], %w[ApplicationJob job]])
      expect([t.unknown, t.selection]).to eq([['model:Nope'], %w[model:Micropost job:ApplicationJob]])
      expect(t.events.first.lanes).to eq([0, 1])
    end
  end

  it 'positions commits in the window and exports a timeline' do
    timeline(%w[Micropost job:ApplicationJob]) do |t|
      expect([t.position(now.iso8601), t.position('2020-01-01T00:00:00Z')]).to eq([1.0, 0.0])
      expect(t.mermaid).to start_with("timeline\n  title Micropost, ApplicationJob, 365d\n")
    end
  end

  it 'suggests the most-changed units when nothing is selected' do
    timeline(nil) do |t|
      expect(t).to be_empty
      expect(t.suggestions.first(2).pluck('identifier')).to contain_exactly('ApplicationJob', 'Micropost')
    end
  end
end
