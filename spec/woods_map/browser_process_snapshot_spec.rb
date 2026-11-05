# frozen_string_literal: true

require_relative '../support/browser_process_snapshot'

RSpec.describe WoodsMap::BrowserProcessSnapshot do
  it 'keeps portable liveness and pipe state when proc is unavailable' do
    IO.pipe do |reader, writer|
      state = described_class.capture(Process.pid, { replies: reader, commands: writer },
                                      proc_root: '/nonexistent-wds151-proc')
      expect(state).to include(pid: Process.pid, alive: true)
      expect(state.fetch(:pipes).values).to all(include(closed: false, flags: be_an(Integer)))
      expect(state.fetch(:proc).values).to all(eq('Errno::ENOENT'))
    end
  end

  it 'bounds each proc file without collecting environment or profile files' do
    Dir.mktmpdir do |root|
      base = File.join(root, Process.pid.to_s)
      FileUtils.mkdir_p(File.join(base, 'fdinfo'))
      %w[stat status wchan fdinfo/3 fdinfo/4 environ].each do |name|
        File.write(File.join(base, name), 'x' * 10_000)
      end
      state = described_class.capture(Process.pid, {}, proc_root: root)
      expect(JSON.generate(state).bytesize).to be < 11_000
      expect(state.fetch(:proc).keys).not_to include('environ')
      expect(state.fetch(:proc).fetch('status').bytesize).to eq(2048)
    end
  end
end
