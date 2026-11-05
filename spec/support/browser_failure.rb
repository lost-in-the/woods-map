# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'tmpdir'

module WoodsMap
  # Opt-in failure evidence for synthetic browser fixtures, outside their temporary profile.
  module BrowserFailure
    # @param source [String] failed session directory after browser cleanup
    # @param error [StandardError] original failure, which collection must not replace
    # @param state [Hash] bounded protocol context, without fixture source duplication
    # @return [void]
    def self.save(source, error, state)
      root = ENV.fetch('WOODS_MAP_BROWSER_ARTIFACTS', nil)
      return if root.to_s.empty?

      FileUtils.mkdir_p(root)
      destination = Dir.mktmpdir('session-', root)
      %w[page.html chromium.log].each do |name|
        path = File.join(source, name)
        FileUtils.cp(path, destination) if File.file?(path)
      end
      details = state.merge(error: error.class.name, message: error.message)
      File.write(File.join(destination, 'failure.json'), JSON.pretty_generate(details))
      warn "Browser failure evidence: #{destination}"
    rescue StandardError => e
      warn "Browser evidence collection failed: #{e.class}: #{e.message}"
    end
  end
end
