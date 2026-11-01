# frozen_string_literal: true

require 'json'
require 'io/wait'
require 'io/nonblock'
require 'tmpdir'
require 'timeout'
require 'uri'

module WoodsMap
  # Runs frame- and focus-sensitive fixtures in real time. Chromium's virtual-time
  # DOM dump can advance timers before a frame or native focus event is delivered.
  # The DevTools pipe needs neither a listening port nor a browser-driver gem.
  class BrowserSession
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
    # @return [Object] the fixture's parsed JSON report
    def self.run(html, fragment: '', result_timeout: 10)
      Dir.mktmpdir('woods-map-session') do |directory|
        fixture = File.join(directory, 'page.html')
        File.write(fixture, html)
        session = new(directory)
        begin
          url = "file://#{URI::DEFAULT_PARSER.escape(fixture)}#{fragment}"
          session.result(url, result_timeout)
        ensure
          session.close
        end
      end
    end

    # @param directory [String] temporary fixture, profile and diagnostic directory
    def initialize(directory)
      @command_reader, @commands = IO.pipe
      @replies, @reply_writer = IO.pipe
      @log = File.open(File.join(directory, 'chromium.log'), 'w+')
      # Ruby creates nonblocking pipes; Chromium treats EAGAIN as a closed pipe.
      @command_reader.nonblock = false
      @reply_writer.nonblock = false
      @pid = Process.spawn(ENV.fetch('WOODS_MAP_BROWSER'), '--headless', '--disable-gpu',
                           '--disable-background-networking', '--no-first-run', '--remote-debugging-pipe',
                           "--user-data-dir=#{File.join(directory, 'profile')}",
                           3 => @command_reader, 4 => @reply_writer, out: @log, err: @log, pgroup: true)
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
    # @return [Object] the fixture's parsed JSON report
    def result(url, timeout)
      target = command('Target.createTarget', { url: 'about:blank' }).fetch('targetId')
      @session = command('Target.attachToTarget', { targetId: target, flatten: true }).fetch('sessionId')
      command('Page.enable')
      command('Runtime.enable')
      command('Page.setLifecycleEventsEnabled', { enabled: true })
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

    def command(method, params = {}, timeout: 10)
      id = @sequence += 1
      message = { id: id, method: method, params: params }
      message[:sessionId] = @session if @session
      @commands.write("#{JSON.generate(message)}\0")
      @commands.flush
      deadline = clock + timeout
      loop do
        reply = receive(deadline)
        if reply['id'] == id
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
      end
    rescue EOFError
      @log.rewind
      raise "Chromium closed its DevTools pipe: #{@log.read}"
    end

    def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
