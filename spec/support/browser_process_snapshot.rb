# frozen_string_literal: true

require 'fcntl'

module WoodsMap
  # Bounded, passive failure snapshot of this session only; never runs a command.
  module BrowserProcessSnapshot
    # @param pid [Integer] this session's spawned process
    # @param pipes [Hash{Symbol => IO}] parent ends of the DevTools pipes
    # @param proc_root [String] optional Linux proc filesystem
    # @return [Hash] best-effort state, without command lines, environment or profiles
    def self.capture(pid, pipes, proc_root: '/proc')
      state = { pid: pid, alive: alive?(pid), pipes: pipes.transform_values { |io| pipe(io) } }
      base = File.join(proc_root, pid.to_s)
      state[:proc] = {}
      %w[stat status wchan fdinfo/3 fdinfo/4].each do |name|
        state[:proc][name] = read(File.join(base, name))
      end
      state[:proc][:fd3] = link(File.join(base, 'fd/3'))
      state[:proc][:fd4] = link(File.join(base, 'fd/4'))
      state
    rescue StandardError => e
      { unavailable: e.class.name }
    end

    class << self
      private

      def alive?(pid)
        Process.kill(0, pid)
        true
      rescue Errno::ESRCH
        false
      end

      def pipe(io)
        return { closed: true } if io.closed?

        { closed: false, fd: io.fileno, flags: io.fcntl(Fcntl::F_GETFL),
          close_on_exec: io.close_on_exec? }
      rescue StandardError => e
        { unavailable: e.class.name }
      end

      def read(path)
        File.open(path, 'r') { |file| file.read(2048) }
      rescue StandardError => e
        e.class.name
      end

      def link(path)
        File.readlink(path).byteslice(0, 256)
      rescue StandardError => e
        e.class.name
      end
    end
  end
end
