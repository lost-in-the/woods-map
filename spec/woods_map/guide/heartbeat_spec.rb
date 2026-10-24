# frozen_string_literal: true

RSpec.describe WoodsMap::Guide::Heartbeat do
  let(:lock) { Mutex.new }
  let(:written) { [] }

  def heartbeat(interval, write: ->(text) { written << text })
    described_class.new(interval: interval, lock: lock, write: write).start
  end

  it 'writes an SSE comment line after each quiet interval, and nothing once stopped' do
    beat = heartbeat(0.02)
    sleep 0.15
    beat.stop
    count = written.size
    sleep 0.05
    expect(count).to be >= 2
    expect(written.uniq).to eq([": heartbeat\n\n"])
    expect(written.size).to eq(count)
  end

  it 'waits a full interval after the answer writes' do
    beat = heartbeat(0.2)
    5.times do
      sleep 0.05
      lock.synchronize { beat.wrote }
    end
    beat.stop
    expect(written).to be_empty
  end

  it 'sends nothing at 0' do
    beat = heartbeat(0)
    sleep 0.03
    beat.stop
    expect(written).to be_empty
  end

  it 'marks the client gone when a write fails' do
    beat = heartbeat(0.01, write: ->(_) { raise IOError, 'closed stream' })
    sleep 0.05
    beat.stop
    expect(beat).to be_gone
  end
end
