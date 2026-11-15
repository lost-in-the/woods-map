# frozen_string_literal: true

RSpec.describe WoodsMap::TrailWalkthrough do
  let(:repository) { instance_double(WoodsMap::Repository) }
  let(:pin) { WoodsMap::TrailBoard::Pin.new(type: 'job', identifier: 'Job') }

  def cards(source)
    allow(repository).to receive(:unit).with('Job', type: 'job').and_return('source_code' => source)
    described_class.new(repository, [pin]).cards
  end

  it 'bounds long excerpts by both lines and characters' do
    expect(cards("line\n" * 30).first).to include(excerpt: "line\n" * 20, truncated: true)
    expect(cards('x' * 5000).first).to include(excerpt: 'x' * 4000, truncated: true)
  end

  it 'does not invent source for units without a published body' do
    expect(cards(nil).first).to include(present: true, excerpt: '', truncated: false)
  end

  it 'retains missing typed units in the reading order' do
    allow(repository).to receive(:unit).with('Job', type: 'job').and_return(nil)
    expect(described_class.new(repository, [pin]).cards.first).to include(pin: pin, present: false, excerpt: nil)
  end
end
