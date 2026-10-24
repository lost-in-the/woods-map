# frozen_string_literal: true

RSpec.describe WoodsMap::TrailBoard do
  def board(**params)
    described_class.from_params(params)
  end

  it 'reads an entry, typed pins, a generation and a hop budget' do
    b = board(entry: 'Post@after_commit(create)', pin: ['model:Admin::Post', 'job:NotifyJob'], gen: '4', hops: '3')
    expect(b).to have_attributes(entry: 'Post@after_commit(create)', entry_unit: 'Post', gen: 4, hops: 3)
    expect(b.pins.map(&:to_param)).to eq(%w[model:Admin::Post job:NotifyJob])
    expect(b.pins.first.identity).to eq(%w[Admin::Post model])
  end

  it 'drops what is not an identifier or a number, and keeps the defaults' do
    b = board(entry: 'rm -rf /', pin: ['nonsense', 'model:Post', 'model:Post'], gen: 'latest', hops: '9')
    expect(b).to have_attributes(entry: nil, rejected_entry: 'rm -rf /', gen: nil, hops: 2)
    expect(b.pins.map(&:to_param)).to eq(['model:Post'])
    expect(b.rejected_pins).to eq(['nonsense'])
  end

  it 'holds at most the pin limit' do
    b = board(pin: (1..30).map { |n| "model:M#{n}" })
    expect(b.pins.size).to eq(described_class::MAX_PINS)
    expect(b.rejected_pins.size).to eq(6)
  end

  it 'builds queries with a pin added or removed, the default budget left out' do
    b = board(entry: 'Post@create', pin: ['model:Post'])
    pin = described_class::Pin.new(type: 'job', identifier: 'NotifyJob')
    expect(b.with_pin(pin)).to eq('entry' => 'Post@create', 'pin' => %w[model:Post job:NotifyJob])
    expect(b.without_pin(b.pins.first)).to eq('entry' => 'Post@create')
  end

  it 'keys notes by entry, pins and generation, not by the hop budget' do
    expect(board(entry: 'A#b', pin: %w[model:X], hops: '1').key).to eq(board(entry: 'A#b', pin: %w[model:X]).key)
    expect(board(entry: 'A#b', gen: '2').key).not_to eq(board(entry: 'A#b').key)
  end
end
