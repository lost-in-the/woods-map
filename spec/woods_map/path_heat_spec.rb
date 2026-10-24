# frozen_string_literal: true

RSpec.describe WoodsMap::PathHeat do
  def table(paths, dates)
    commits = dates.map { |sha, date| { 'sha' => sha, 'date' => date } }
    instance_double(Woods::PublishedIndex::CommitTable, commits: commits, paths: paths)
  end

  let(:now) { Time.utc(2026, 10, 18) }

  it 'reads hot, active and settled from how recently and how often a file changed' do
    heat = described_class.new(
      table({ 'hot.rb' => %w[a b c], 'active.rb' => %w[d], 'old.rb' => %w[e] },
            { 'a' => '2026-10-17T00:00:00Z', 'b' => '2026-10-10T00:00:00Z', 'c' => '2026-10-01T00:00:00Z',
              'd' => '2026-08-01T00:00:00Z', 'e' => '2025-11-01T00:00:00Z' }),
      now: now
    )

    expect(%w[hot.rb active.rb old.rb missing.rb].map { |path| heat.level(path) }).to eq(%w[h3 h2 h1 h1])
    expect(heat.describe('hot.rb')).to eq('hot: 3 commits in the commit table, hot.rb')
  end
end
