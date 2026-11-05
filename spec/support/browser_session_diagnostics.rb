# frozen_string_literal: true

require_relative 'browser_failure'
require_relative 'browser_process_snapshot'

module WoodsMap
  # Failure-only observations around the unchanged session lifecycle.
  module BrowserSessionDiagnostics
    # Capture while this session still owns its live process and open pipes.
    # @return [void]
    def capture_failure
      @timing[:failure] = clock
      return if ENV.fetch('WOODS_MAP_BROWSER_ARTIFACTS', nil).to_s.empty?

      @live = BrowserProcessSnapshot.capture(@pid, { commands: @commands, replies: @replies })
    rescue StandardError
      nil
    end

    # @param directory [String] temporary fixture and closed browser log directory
    # @param error [StandardError] original session failure
    # @return [void]
    def retain_failure(directory, error)
      BrowserFailure.save(directory, error, { command: @last_command, events: @events.last(50),
                                              timing: @timing, live: @live, buffered_bytes: @buffer.bytesize })
    end

    private

    def close_pipes
      [@command_reader, @commands, @replies, @reply_writer, @log].compact.each do |io|
        io.close unless io.closed?
      end
    end

    def terminate(signal)
      Process.kill(signal, -@pid)
    rescue Errno::ESRCH
      nil
    end
  end
end
