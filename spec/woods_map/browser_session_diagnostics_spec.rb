# frozen_string_literal: true

require_relative '../support/browser_session'

RSpec.describe WoodsMap::BrowserSessionDiagnostics do
  it 'preserves the exact session exception through collection and cleanup' do
    session = instance_double(WoodsMap::BrowserSession)
    error = RuntimeError.new('original failure')
    allow(WoodsMap::BrowserSession).to receive(:new).and_return(session)
    allow(session).to receive(:result).and_raise(error)
    allow(session).to receive(:capture_failure)
    allow(session).to receive(:close)
    allow(session).to receive(:retain_failure)
    expect { WoodsMap::BrowserSession.run('') }.to(raise_error { |raised| expect(raised).to equal(error) })
  end

  it 'absorbs a snapshot failure before cleanup' do
    session = WoodsMap::BrowserSession.allocate
    session.instance_variable_set(:@timing, {})
    allow(ENV).to receive(:fetch).with('WOODS_MAP_BROWSER_ARTIFACTS', nil).and_return('/unused')
    allow(WoodsMap::BrowserProcessSnapshot).to receive(:capture).and_raise(IOError)
    expect { session.capture_failure }.not_to raise_error
  end
end
