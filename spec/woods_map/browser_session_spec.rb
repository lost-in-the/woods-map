# frozen_string_literal: true

require_relative '../support/browser_session'

RSpec.describe WoodsMap::BrowserSession do
  before { skip 'Set WOODS_MAP_BROWSER to run Chromium' unless ENV['WOODS_MAP_BROWSER'] }

  it 'waits for an animation-frame report rather than stopping at page load' do
    html = '<pre id="result"></pre><script>requestAnimationFrame(() => {' \
           'document.querySelector("#result").textContent = JSON.stringify({frame: true}) })</script>'

    expect(described_class.run(html)).to eq('frame' => true)
  end

  it 'reports a script exception instead of waiting for a missing result' do
    expect { described_class.run('<script>throw new Error("fixture exploded")</script>') }
      .to raise_error(RuntimeError, /Browser script failed:.*fixture exploded/)
  end

  it 'bounds a fixture that never reports by wall time' do
    expect { described_class.run('<pre id="result"></pre>', result_timeout: 0.1) }
      .to raise_error(RuntimeError, /wall-time deadline/)
  end

  it 'closes its pipes and log when the browser cannot start' do
    opened = []
    allow(IO).to(receive(:pipe).and_wrap_original { |method| method.call.tap { |ends| opened.concat(ends) } })
    allow(File).to(receive(:open).and_wrap_original do |method, *args|
      method.call(*args).tap do |file|
        opened << file
      end
    end)
    allow(Process).to receive(:spawn).and_raise(Errno::ENOENT, 'missing browser')

    expect { described_class.run('') }.to raise_error(Errno::ENOENT, /missing browser/)
    expect(opened).not_to be_empty
    expect(opened).to all(be_closed)
  end
end
