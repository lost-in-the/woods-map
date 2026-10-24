# frozen_string_literal: true

RSpec.describe WoodsMap::Guide::ServerPool do
  # A server that only records whether it was stopped.
  let(:server_class) do
    Class.new do
      attr_reader :closed

      def close
        @closed = true
      end
    end
  end

  let(:now) { [0.0] }
  let(:pool) { described_class.new(size: 2, idle: 600, wait: 0.05, clock: -> { now.first }) }
  let(:this_generation) { ['stdio', [1]] }
  let(:next_generation) { ['stdio', [2]] }

  def checkout(key = this_generation)
    pool.checkout(key) { server_class.new }
  end

  it 'hands the same server to the next answer once the last one ended cleanly' do
    first = checkout
    pool.checkin(first, reuse: true)
    expect(checkout).to be(first)
    expect(first.closed).to be_nil
  end

  it 'starts a server only when none is idle, and never more than its size' do
    pool = described_class.new(size: 2, idle: 600, wait: 0.05)
    built = 0
    a = pool.checkout(this_generation) { built += 1 and server_class.new }
    b = pool.checkout(this_generation) { built += 1 and server_class.new }
    expect(a).not_to be(b)
    expect do
      pool.checkout(this_generation) do
        built += 1 and server_class.new
      end
    end.to raise_error(described_class::Busy, /2 guide index servers/)
    expect(built).to eq(2)
    expect(pool.stats).to eq(alive: 2, busy: 2, idle: 0)
  end

  it 'lets a waiting answer take a server handed back meanwhile' do
    pool = described_class.new(size: 1, idle: 600, wait: 2)
    first = pool.checkout(this_generation) { server_class.new }
    waiter = Thread.new { pool.checkout(this_generation) { server_class.new } }
    sleep 0.05
    pool.checkin(first, reuse: true)
    expect(waiter.value).to be(first)
  end

  it 'stops a server that comes back from an answer that did not end cleanly' do
    first = checkout
    pool.checkin(first, reuse: false)
    expect(first.closed).to be(true)
    expect(checkout).not_to be(first)
  end

  it 'restarts on a new generation: idle servers of the old one stop at once, busy ones when they return' do
    idle = checkout
    busy = checkout
    pool.checkin(idle, reuse: true)
    fresh = checkout(next_generation)
    expect(idle.closed).to be(true)
    expect(fresh).not_to be(busy)
    pool.checkin(busy, reuse: true)
    expect(busy.closed).to be(true)
    expect(pool.stats).to eq(alive: 1, busy: 1, idle: 0)
  end

  it 'stops a server left idle past its time' do
    first = checkout
    pool.checkin(first, reuse: true)
    now[0] = 601.0
    second = checkout
    expect(first.closed).to be(true)
    expect(second).not_to be(first)
  end

  it 'gives the slot back when a server fails to start' do
    expect { pool.checkout(this_generation) { raise ArgumentError, 'no woods-mcp' } }.to raise_error(ArgumentError)
    expect(pool.stats).to eq(alive: 0, busy: 0, idle: 0)
  end

  it 'stops idle servers at shutdown and busy ones when they come back' do
    idle = checkout
    busy = checkout
    pool.checkin(idle, reuse: true)
    pool.shutdown
    expect(idle.closed).to be(true)
    expect(busy.closed).to be_nil
    pool.checkin(busy, reuse: true)
    expect(busy.closed).to be(true)
  end

  it 'stops busy servers too when forced, at exit' do
    busy = checkout
    pool.shutdown(force: true)
    expect(busy.closed).to be(true)
    expect(pool.stats).to eq(alive: 0, busy: 0, idle: 0)
  end

  it 'forgets, without stopping, the servers a forked parent started' do
    parent = checkout
    pool.checkin(parent, reuse: true)
    allow(Process).to receive(:pid).and_return(Process.pid + 1)
    child = checkout
    expect(child).not_to be(parent)
    expect(parent.closed).to be_nil
  end

  describe 'WoodsMap::Guide.server_pool' do
    after { WoodsMap::Guide.shutdown_servers }

    it 'is one pool per process for the configured size, none at size 0' do
      config = WoodsMap.configuration
      pool = WoodsMap::Guide.server_pool(config)
      expect(WoodsMap::Guide.server_pool(config)).to be(pool)
      expect(pool.size).to eq(2)
      config.guide_mcp_servers = 0
      expect(WoodsMap::Guide.server_pool(config)).to be_nil
    end
  end
end
