# frozen_string_literal: true

RSpec.describe WoodsMap::DateSpan do
  it 'reads first..last as inclusive days in order and refuses anything else' do
    expect(described_class.parse('2026-10-14..2026-10-05')).to eq(Date.new(2026, 10, 5)..Date.new(2026, 10, 14))
    expect(['', '2026-10-05', '2026-13-01..2026-10-05', '2026-10-05..x', nil].map { |v| described_class.parse(v) })
      .to all(be_nil)
  end

  it 'covers a commit by its UTC day and formats a range back' do
    span = described_class.parse('2026-10-05..2026-10-14')
    expect(described_class.cover?(span, '2026-10-14T23:30:00-01:00')).to be(false)
    expect(described_class.cover?(span, '2026-10-14T23:30:00+00:00')).to be(true)
    expect([described_class.cover?(nil, '2026-10-10T00:00:00Z'), described_class.format(span)])
      .to eq([false, '2026-10-05..2026-10-14'])
  end
end
