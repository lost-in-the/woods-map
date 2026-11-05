# frozen_string_literal: true

require 'json'
require 'io/wait'
require 'io/nonblock'
require 'tmpdir'
require 'timeout'
require 'uri'
require_relative 'browser_session_diagnostics'

module WoodsMap
  # Runs frame- and focus-sensitive fixtures in real time. Chromium's virtual-time
  # DOM dump can advance timers before a frame or native focus event is delivered.
  # The DevTools pipe needs neither a listening port nor a browser-driver gem.
  class BrowserSession
    include BrowserSessionDiagnostics

    RESULT = <<~JS
      new Promise((resolve) => {
        const read = () => {
          const text = document.querySelector("#result")?.textContent
          if (text) { observer.disconnect(); resolve(text) }
        }
        const observer = new MutationObserver(read)
        observer.observe(document, { subtree: true, childList: true, characterData: true })
        read()
      })
    JS

    # @param html [String] a self-contained browser fixture reporting JSON in #result
    # @param fragment [String] initial URL fragment, including its leading #
    # @param result_timeout [Numeric] maximum wall time for the fixture to report
    # @param viewport [Array<Integer>, nil] exact CSS width and height at device scale 1
    # @return [Object] the fixture's parsed JSON report
    def self.run(html, fragment: '', result_timeout: 10, viewport: nil)
      Dir.mktmpdir('woods-map-session') do |directory|
        fixture = File.join(directory, 'page.html')
        File.write(fixture, html)
        session = new(directory)
        begin
          url = "file://#{URI::DEFAULT_PARSER.escape(fixture)}#{fragment}"
          session.result(url, result_timeout, viewport: viewport)
        rescue StandardError => e
          failure = e
          session.capture_failure
          raise
        ensure
          session.close
          session.retain_failure(directory, failure) if failure
        end
      end
    end

    # @param directory [String] temporary fixture, profile and diagnostic directory
    def initialize(directory)
      @timing = { launch_ordinal: BrowserSessionDiagnostics.next_launch_ordinal }
      @command_reader, @commands = IO.pipe
      @replies, @reply_writer = IO.pipe
      @log = File.open(File.join(directory, 'chromium.log'), 'w+')
      # Ruby creates nonblocking pipes; Chromium treats EAGAIN as a closed pipe.
      @command_reader.nonblock = false
      @reply_writer.nonblock = false
      @timing[:spawn_start] = clock
      @pid = Process.spawn(ENV.fetch('WOODS_MAP_BROWSER'), '--headless', '--disable-gpu',
                           '--disable-background-networking', '--no-first-run', '--remote-debugging-pipe',
                           "--user-data-dir=#{File.join(directory, 'profile')}",
                           3 => @command_reader, 4 => @reply_writer, out: @log, err: @log, pgroup: true)
      @timing[:spawn_end] = clock
      @command_reader.close
      @reply_writer.close
      @buffer = +''
      @events = []
      @sequence = 0
    rescue StandardError
      close_pipes
      raise
    end

    # @param url [String] fixture URL
    # @param timeout [Numeric] maximum time waiting for the JSON result
    # @param viewport [Array<Integer>, nil] exact CSS width and height
    # @return [Object] the fixture's parsed JSON report
    def result(url, timeout, viewport: nil)
      target = command('Target.createTarget', { url: 'about:blank' }).fetch('targetId')
      @session = command('Target.attachToTarget', { targetId: target, flatten: true }).fetch('sessionId')
      command('Page.enable')
      command('Runtime.enable')
      command('Page.setLifecycleEventsEnabled', { enabled: true })
      if viewport
        command('Emulation.setDeviceMetricsOverride',
                { width: viewport.first, height: viewport.last, deviceScaleFactor: 1, mobile: false })
      end
      navigation = command('Page.navigate', { url: url })
      raise navigation['errorText'] if navigation['errorText']

      wait_for_load(navigation.fetch('loaderId'))
      params = { expression: RESULT, awaitPromise: true, returnByValue: true }
      reply = command('Runtime.evaluate', params, timeout: timeout)
      raise "Browser script failed: #{reply['exceptionDetails']}" if reply['exceptionDetails']

      JSON.parse(reply.fetch('result').fetch('value'))
    end

    # Close the pipes and reap only this session's isolated browser process group.
    # @return [void]
    def close
      @timing[:cleanup_start] = clock
      @commands.close unless @commands.closed?
      terminate('TERM')
      Timeout.timeout(2) { Process.wait(@pid) }
    rescue Errno::ECHILD
      nil
    rescue Timeout::Error
      terminate('KILL')
      Process.wait(@pid)
    ensure
      close_pipes
      @timing[:cleanup_end] = clock
    end

    private

    def command(method, params = {}, timeout: 10)
      @last_command = method
      id = @sequence += 1
      message = { id: id, method: method, params: params }
      message[:sessionId] = @session if @session
      @timing.delete(:command_reply)
      @timing[:command_send] = clock
      @commands.write("#{JSON.generate(message)}\0")
      @commands.flush
      deadline = clock + timeout
      loop do
        reply = receive(deadline)
        if reply['id'] == id
          @timing[:command_reply] = clock
          raise "DevTools #{method} failed: #{reply['error']}" if reply['error']

          return reply.fetch('result')
        end
        @events << reply
      end
    end

    def wait_for_load(loader)
      deadline = clock + 10
      loop do
        index = @events.index do |event|
          event['method'] == 'Page.lifecycleEvent' && event.dig('params', 'loaderId') == loader &&
            event.dig('params', 'name') == 'load'
        end
        return @events.delete_at(index) if index

        @events << receive(deadline)
      end
    end

    def receive(deadline)
      loop do
        if (boundary = @buffer.index("\0"))
          message = JSON.parse(@buffer.slice!(0, boundary + 1).chop)
          if message['method'] == 'Runtime.exceptionThrown'
            raise "Browser script failed: #{message.dig('params', 'exceptionDetails')}"
          end

          return message
        end
        remaining = deadline - clock
        unless remaining.positive? && @replies.wait_readable(remaining)
          raise 'Browser did not report before the wall-time deadline'
        end

        @buffer << @replies.readpartial(65_536)
        @timing[:first_byte] ||= clock
      end
    rescue EOFError
      @log.rewind
      raise "Chromium closed its DevTools pipe: #{@log.read}"
    end

    def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
