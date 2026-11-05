# frozen_string_literal: true

require_relative '../support/browser_failure'

RSpec.describe WoodsMap::BrowserFailure do
  let(:root) { Dir.mktmpdir }
  let(:destination) { File.join(root, 'artifacts') }
  let(:source) { File.join(root, 'source') }

  after { FileUtils.remove_entry(root) }

  before do
    FileUtils.mkdir_p(source)
    File.write(File.join(source, 'page.html'), '<pre id="result"></pre>')
    File.write(File.join(source, 'chromium.log'), 'browser log')
    allow(ENV).to receive(:fetch).with('WOODS_MAP_BROWSER_ARTIFACTS', nil).and_return(destination)
  end

  it 'copies only the fixture and log with the failure context to unique directories' do
    2.times { described_class.save(source, RuntimeError.new('deadline'), { command: 'Runtime.evaluate' }) }
    directories = Dir.children(destination)
    expect(directories.size).to eq(2)
    saved = File.join(destination, directories.first)
    expect(Dir.children(saved)).to contain_exactly('page.html', 'chromium.log', 'failure.json')
    expect(File.read(File.join(saved, 'chromium.log'))).to eq('browser log')
    expect(JSON.parse(File.read(File.join(saved, 'failure.json'))))
      .to include('message' => 'deadline', 'command' => 'Runtime.evaluate')
  end

  it 'does not collect anything unless explicitly enabled' do
    allow(ENV).to receive(:fetch).with('WOODS_MAP_BROWSER_ARTIFACTS', nil).and_return(nil)
    described_class.save(source, RuntimeError.new('deadline'), {})
    expect(File).not_to exist(destination)
  end

  it 'does not replace the original failure when evidence cannot be written' do
    allow(FileUtils).to receive(:mkdir_p).with(destination).and_raise(Errno::EACCES)
    expect { described_class.save(source, RuntimeError.new('deadline'), {}) }.not_to raise_error
  end
end
