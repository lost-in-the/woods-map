# frozen_string_literal: true

require_relative '../support/range_report_fixture'

RSpec.describe WoodsMap::Since do
  include RangeReportFixture

  let(:repository) do
    repo = instance_double(WoodsMap::Repository, generation_number: 1)
    allow(repo).to receive(:graph_node).and_return({ 'type' => 'model' })
    repo
  end

  it 'is absent without a selector and refuses a malformed one before asking Woods' do
    allow(WoodsMap::ImpactRange).to receive(:new)
    expect(described_class.from_param('', index_dir: 'x', repository: repository)).to be_nil
    since = described_class.from_param('gen:1; drop', index_dir: 'x', repository: repository)
    expect([since.available?,
            since.message]).to eq([false, 'Use since=gen:N or a retained commit SHA (7–40 characters).'])
    expect(WoodsMap::ImpactRange).not_to have_received(:new)
  end

  it 'compares the selector with now through Woods and reads the unit records' do
    stub_range_report
    since = described_class.from_param('gen:1', index_dir: 'x', repository: repository)
    expect(WoodsMap::ImpactRange).to have_received(:new).with('x', from: 'gen:1', to: 'now')
    expect(since.change('User', 'model')['status']).to eq('modified')
    expect(since.reach('UsersController', 'controller')['distance']).to eq(1)
    expect(since.reach('Gone', 'service')).to be_nil
  end

  it 'marks an area only when a key it reads moved' do
    stub_range_report
    since = described_class.from_param('gen:1', index_dir: 'x', repository: repository)
    expect(%i[callbacks associations validations].map { |area| since.area_changed?('User', 'model', area) })
      .to eq([true, false, false])
  end

  it 'passes on Woods\' message when the generation is not retained' do
    range = instance_double(WoodsMap::ImpactRange, state: :invalid,
                                                   message: 'Selector "gen:9" does not identify one retained payload')
    allow(WoodsMap::ImpactRange).to receive(:new).and_return(range)
    since = described_class.from_param('gen:9', index_dir: 'x', repository: repository)
    expect([since.available?, since.message]).to eq([false, 'Selector "gen:9" does not identify one retained payload'])
  end

  describe '#line_marks' do
    def since_with(changes, to: 1)
      data = range_report_data
      data['range']['to']['generation'] = to
      record = range_report_changes.first.merge('source_changes' => changes)
      stub_range_report(data.merge('changed' => [record]))
      described_class.from_param('gen:1', index_dir: 'x', repository: repository)
    end

    it "reads the report's after-side ranges as changed lines and removal points" do
      hunks = [{ 'before' => [3, 2], 'after' => [3, 3] }, { 'before' => [9, 1], 'after' => [9, 0] },
               { 'before' => [1, 1], 'after' => [0, 0] }]
      marks = since_with({ 'hunks' => hunks, 'added_lines' => 3, 'removed_lines' => 4, 'coverage' => 'truncated' })
              .line_marks('User', 'model')
      expect(marks.changed.to_a.sort).to eq([3, 4, 5])
      expect([marks.removed_count(9), marks.removed_count(3), marks.coverage]).to eq([1, 0, 'truncated'])
    end

    it 'marks nothing past the bounds, without ranges, or when now is another generation' do
      ranges = { 'hunks' => [{ 'before' => [1, 1], 'after' => [1, 1] }], 'coverage' => 'complete' }
      expect(since_with(ranges.merge('coverage' => 'too_large')).line_marks('User', 'model')).to be_nil
      expect(since_with(nil).line_marks('User', 'model')).to be_nil
      expect(since_with(ranges, to: 2).line_marks('User', 'model')).to be_nil
    end
  end

  it 'reads the columns a record names as moved, added before modified before removed' do
    record = range_report_changes.first.merge('column_changes' => { 'added' => %w[zeta alpha], 'modified' => ['mid'],
                                                                    'removed' => ['old'] })
    stub_range_report(range_report_data.merge('changed' => [record]))
    marks = described_class.from_param('gen:1', index_dir: 'x', repository: repository).column_marks('User', 'model')
    expect([marks['alpha'], marks['mid'], marks['old'], marks.summary])
      .to eq([:added, :modified, nil, '+alpha +zeta ~mid −old'])
    expect(described_class.from_param('gen:1', index_dir: 'x', repository: repository).column_marks('Nope', 'model'))
      .to be_nil
  end
end
