# frozen_string_literal: true

require_relative '../support/range_report_fixture'

RSpec.describe WoodsMap::RangeReport do
  include RangeReportFixture

  subject(:report) { described_class.new(range_report_data, repository: repository, focus: ['users/show.html.erb']) }

  let(:repository) do
    repo = instance_double(WoodsMap::Repository, generation_number: 1)
    allow(repo).to receive(:graph_node) { |id, type: nil|
      %w[User users/show.html.erb UsersController].include?(id) ? { 'type' => type } : nil
    }
    repo
  end

  it 'counts the tabs from the report records only' do
    expect(described_class::LENSES.index_with { |lens| report.count(lens) })
      .to eq('overview' => nil, 'changed' => 2, 'risks' => 1, 'flows' => 0, 'tests' => 0, 'graph' => 4, 'unknown' => 2)
  end

  it 'links only records of the pinned generation that the generation has' do
    expect(report.affected.map { |a| report.current?(a) }).to eq([true, false])
    expect(report.current?(report.changed.first,
                           generation: report.generation_of_change(report.changed.first))).to be(true)
  end

  it 'centres the graph on the focused change and emphasises changes at distance 0' do
    expect(report.graph_centre).to eq('identifier' => 'users/show.html.erb', 'type' => 'view_template')
    expect(report.emphasis.map { |e| [e.identifier, e.distance] })
      .to eq([['User', 0], ['users/show.html.erb', 0], ['UsersController', 1]])
  end

  it 'finds the affected records whose witness paths start at a change' do
    expect(report.reached_from(report.changed.first).pluck('identifier')).to eq(['UsersController'])
    expect(report.reached_from(report.changed.last)).to eq([])
  end

  it 'reads the endpoints and short SHAs as Woods recorded them' do
    expect([report.from_generation, report.sha('from'), report.sha('to'),
            report.complete?]).to eq([1, 'a1b2c3d', '9f8e7d6', false])
  end
end
