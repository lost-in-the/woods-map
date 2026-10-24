# frozen_string_literal: true

RSpec.describe WoodsMap::GenerationStrip do
  def generation(number, table: true, baseline: false)
    WoodsMap::CommitLedger::Generation.new(number: number, table: table, baseline: baseline, introduced: [])
  end

  let(:ledger) do
    instance_double(WoodsMap::CommitLedger, generations: [generation(1, baseline: true), generation(2, table: false),
                                                          generation(3), generation(4)])
  end

  def commit(number)
    WoodsMap::CommitRows::Commit.new(generation: number && generation(number))
  end

  it 'draws one bar per retained generation with a table, the pinned one hot' do
    strip = described_class.new([commit(4), commit(4), commit(3), commit(1), commit(nil)], ledger, current: 4)

    expect(strip.buckets.map { |bar| [bar.first, bar.count, bar.recent] }).to eq([[1, 1, false], [3, 1, false],
                                                                                  [4, 2, true]])
    expect(strip).to have_attributes(total: 4, recent_total: 2, peak: 2, step: nil, marks: [])
    expect(strip.ticks).to eq([[0, 'gen 1'], [1, 'gen 3'], [2, 'gen 4']])
  end

  it 'keeps every bar inside the view box, the tallest at full height' do
    strip = described_class.new([commit(4), commit(4), commit(3)], ledger, current: 4)

    expect(strip.buckets.last.height).to eq(WoodsMap::CommitStrip::HEIGHT)
    expect(strip.buckets.map(&:x).max + described_class::BAR).to eq(strip.width)
  end

  it 'says a baseline bar holds commits only known to be at or before it' do
    strip = described_class.new([commit(1), commit(3)], ledger, current: 4)

    expect(strip.buckets.map(&:label)).to eq(['1 commit already in gen 1, the oldest retained table',
                                              '1 commit first carried by gen 3', '0 commits first carried by gen 4'])
  end
end
