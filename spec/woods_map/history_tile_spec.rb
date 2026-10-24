# frozen_string_literal: true

RSpec.describe WoodsMap::HistoryTile do
  let(:now) { Time.utc(2026, 10, 24) }
  let(:git) do
    { 'commit_count' => 4, 'last_author' => 'Ada', 'last_modified' => '2026-10-20T10:00:00Z',
      'change_frequency' => 'active',
      'contributors' => [{ 'name' => 'Ada', 'commits' => 2 }, { 'name' => 'Grace', 'commits' => 2 }] }
  end
  let(:unit) do
    { 'identifier' => 'Widget', 'type' => 'model', 'file_path' => 'app/models/widget.rb',
      'metadata' => { 'git' => git } }
  end

  def rows(repository)
    described_class.new(repository, unit, now: now).tile[:rows].to_h
  end

  it 'labels the churn with the window Woods counts' do
    repository = instance_double(WoodsMap::Repository, commit_table_state: :absent)
    expect(rows(repository)['churn']).to include(text: '4 commits in 365d')
  end

  it 'says the people are the top contributors Woods lists when there is no commit table' do
    repository = instance_double(WoodsMap::Repository, commit_table_state: :absent)
    expect(rows(repository)['people']).to eq('top 2 contributors')
  end

  it 'counts every author of the window from the commit table' do
    table = Object.new
    def table.commits_for(*)
      [%w[Ada 2026-10-01], %w[Grace 2026-06-01], %w[Linus 2026-01-02], %w[Ada 2026-09-01], %w[Ken 2024-01-01]]
        .map { |author, day| { 'author' => author, 'date' => "#{day}T00:00:00Z" } }
    end
    repository = instance_double(WoodsMap::Repository, commit_table_state: :available, git_commits: table)
    allow(WoodsMap::UnitPaths).to receive(:for).and_return(['app/models/widget.rb'])
    expect(rows(repository)['people']).to eq('3 authors in 365d')
  end
end
