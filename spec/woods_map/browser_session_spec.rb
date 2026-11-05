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

  it 'retains timeout evidence after cleanup without changing the deadline failure' do # rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations
    Dir.mktmpdir do |root|
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('WOODS_MAP_BROWSER_ARTIFACTS', nil).and_return(root)
      expect { described_class.run('<pre id="result"></pre>', result_timeout: 0.1) }
        .to raise_error(RuntimeError, /wall-time deadline/)
      expect(Dir.children(root).size).to eq(1)
      saved = Dir.glob(File.join(root, '*')).first
      expect(File.read(File.join(saved, 'page.html'))).to include('result')
      details = JSON.parse(File.read(File.join(saved, 'failure.json')))
      expect(details).to include('command' => 'Runtime.evaluate', 'error' => 'RuntimeError',
                                 'launch_ordinal' => be_positive)
      expect(details.fetch('live')).to include('alive' => true, 'pid' => be_positive)
      expect(details.fetch('live').fetch('pipes').values).to all(include('closed' => false))
      times = details.fetch('timing')
      expect(times.fetch('failure')).to be < times.fetch('cleanup_start')
      expect(times.fetch('cleanup_start')).to be <= times.fetch('cleanup_end')
      expect(times.fetch('spawn_start')).to be <= times.fetch('spawn_end')
      expect(times.fetch('first_byte')).to be < times.fetch('failure')
    end
  end

  it 'does not retain successful sessions when collection is enabled' do
    Dir.mktmpdir do |root|
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('WOODS_MAP_BROWSER_ARTIFACTS', nil).and_return(root)
      expect(described_class.run('<pre id="result">{"ok":true}</pre>')).to eq('ok' => true)
      expect(Dir.children(root)).to be_empty
    end
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
