# frozen_string_literal: true

RSpec.describe WoodsMap::RateLimiter do
  let(:now) { [100.0] }
  let(:limiter) { described_class.new(limit: 2, period: 60, max_keys: 3, clock: -> { now.first }) }

  it 'allows the budget, refuses past it and says when the window resets' do
    expect(Array.new(2) { limiter.hit('a') }).to all(be_allowed)
    now[0] = 130.2
    decision = limiter.hit('a')
    expect(decision).not_to be_allowed
    expect(decision.to_h).to include(limit: 2, remaining: 0, retry_after: 30)
  end

  it 'opens a new window once the period has passed' do
    3.times { limiter.hit('a') }
    now[0] = 160.0
    expect(limiter.hit('a')).to be_allowed
  end

  it 'counts each key apart' do
    2.times { limiter.hit('a') }
    expect(limiter.hit('b')).to be_allowed
  end

  it 'bounds memory: expired windows go first, then the oldest' do
    limiter.hit('a')
    now[0] = 170.0
    %w[b c d].each { |key| limiter.hit(key) }
    expect(limiter.size).to eq(3)
    limiter.hit('e')
    expect(limiter.size).to eq(3)
    expect(limiter.hit('b').remaining).to eq(1)
  end

  it 'is shared by the configuration until the budget changes' do
    config = WoodsMap::Configuration.new
    first = config.rate_limiter
    expect(config.rate_limiter).to be(first)
    config.rate_limit = 5
    expect(config.rate_limiter).not_to be(first)
    expect(config.rate_limiter.limit).to eq(5)
  end

  it 'turns off with a nil or zero budget' do
    config = WoodsMap::Configuration.new
    expect(config).to be_rate_limited
    config.rate_limit = nil
    expect(config).not_to be_rate_limited
    config.rate_limit = 0
    expect(config).not_to be_rate_limited
  end
end
