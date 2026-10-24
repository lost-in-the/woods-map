# frozen_string_literal: true

RSpec.describe WoodsMap::Retention do
  describe '.read' do
    it 'answers Woods\' pins, ascending' do
      allow(Woods::PublishedIndex).to receive(:retention_pins).with(FIXTURE_INDEX).and_return([3, 1])
      retention = described_class.read(FIXTURE_INDEX)
      expect([retention.state, retention.pins]).to eq([:available, [1, 3]])
    end

    it 'reports unreadable pin state instead of no pins' do
      allow(Woods::PublishedIndex).to receive(:retention_pins).and_raise(IOError, 'malformed')
      expect(described_class.read(FIXTURE_INDEX)).to have_attributes(state: :unreadable, pins: [])
    end

    it 'reports a Woods without the pin reader as unsupported' do
      allow(Woods::PublishedIndex).to receive(:respond_to?).and_call_original
      allow(Woods::PublishedIndex).to receive(:respond_to?).with(:retention_pins).and_return(false)
      expect(described_class.read(FIXTURE_INDEX).state).to eq(:unsupported)
    end
  end

  it 'names pins whose payload is gone' do
    expect(described_class.new(:available, [1, 4]).missing([1, 2, 3])).to eq([4])
  end

  it 'describes a generation for a rail or a picker' do
    retention = described_class.new(:available, [2])
    expect([retention.describe(2), retention.describe(3), described_class.new(:unsupported).describe(2)])
      .to eq(['pinned', 'not pinned', 'pins unknown'])
  end

  describe '#fallback' do
    it 'lists the pinned generations' do
      expect(described_class.new(:available, [1, 2]).fallback).to eq('Pinned, so kept past retention: gen 1, gen 2.')
    end

    it 'says how to pin when nothing is pinned' do
      expect(described_class.new(:available, []).fallback).to include('bin/rails woods:pin[N]')
    end

    it 'never reads an unknown pin state as no pins' do
      expect([described_class.new(:unreadable).fallback, described_class.new(:unsupported).fallback])
        .to all(not_include('No generation is pinned'))
    end
  end
end
