# frozen_string_literal: true

require 'open3'

RSpec.describe WoodsMap do
  let(:script) { File.expand_path('../.github/scripts/browser-preflight', __dir__) }

  it 'accepts initialized Chrome and cleans its isolated profile' do
    expect(preflight('echo "<html></html>"')).to include(status: 0, cleaned: true)
  end

  it 'fails when Chrome returns success without a DOM' do
    expect(preflight('exit 0')).to include(status: 65, cleaned: true)
  end

  it 'preserves a browser startup error without retrying' do
    expect(preflight('exit 7')).to include(status: 7, launches: 1, cleaned: true)
  end

  it 'fails explicitly when the external startup bound expires' do
    expect(preflight('exit 0', timeout_status: 124)).to include(status: 124, launches: 0)
  end

  # @param browser [String] controlled fake browser behavior
  # @param timeout_status [Integer, nil] controlled timeout command outcome
  # @return [Hash] exit, launch count, profile cleanup and emitted timing contract
  def preflight(browser, timeout_status: nil)
    Dir.mktmpdir do |root|
      bin = File.join(root, 'bin')
      FileUtils.mkdir_p(bin)
      executable(bin, 'date', 'echo 1000')
      executable(bin, 'timeout', timeout_status ? "exit #{timeout_status}" : 'shift 2; exec "$@"')
      executable(bin, 'chrome', browser_script(browser))
      env = { 'PATH' => "#{bin}:#{ENV.fetch('PATH')}", 'WOODS_MAP_BROWSER' => File.join(bin, 'chrome') }
      output, _error, status = Open3.capture3(env, 'bash', script, chdir: root)
      expect(output).to include('preflight_status=', 'preflight_elapsed_ms=')
      launches = File.exist?(File.join(root, 'launches')) ? File.readlines(File.join(root, 'launches')) : []
      profiles = launches.map(&:strip)
      { status: status.exitstatus, launches: profiles.size, cleaned: profiles.none? { |path| File.exist?(path) } }
    end
  end

  # @param behavior [String] fake browser's output/exit behavior
  # @return [String] record every invocation and verify the isolated profile exists
  def browser_script(behavior)
    <<~SH
      for arg in "$@"; do
        case "$arg" in --user-data-dir=*) profile=${arg#*=} ;; esac
      done
      test -d "$profile" || exit 91
      printf '%s\n' "$profile" >> launches
      #{behavior}
    SH
  end

  # @param directory [String] fake executable directory
  # @param name [String] command name
  # @param body [String] shell implementation
  # @return [void]
  def executable(directory, name, body)
    path = File.join(directory, name)
    File.write(path, "#!/bin/sh\n#{body}\n")
    File.chmod(0o755, path)
  end
end
