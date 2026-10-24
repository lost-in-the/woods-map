# frozen_string_literal: true

RSpec.describe WoodsMap::ListPage do
  let(:rows) { (1..7).to_a }

  it 'slices the requested page and says where it sits' do
    page = described_class.new(rows, '2', per: 3)
    expect([page.items, page.number, page.pages, page.first_row, page.last_row]).to eq([[4, 5, 6], 2, 3, 4, 6])
    expect(page).to be_paged
  end

  it 'starts at page 1 for a missing or malformed page and clamps past the end' do
    expect([nil, ['2'], '0', '-1', 'x'].map { |param| described_class.new(rows, param, per: 3).number }).to all(eq(1))
    expect(described_class.new(rows, '99', per: 3).items).to eq([7])
  end

  it 'is one empty page for an empty list' do
    page = described_class.new([], '3', per: 3)
    expect([page.items, page.pages, page.first_row, page.last_row, page.paged?]).to eq([[], 1, 0, 0, false])
  end
end
