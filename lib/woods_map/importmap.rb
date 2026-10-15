# frozen_string_literal: true

require 'digest'
require 'json'
require 'pathname'

module WoodsMap
  # The engine's own import map. Pins name the vendored modules under
  # `vendor/javascript/` and the engine's own code under `app/javascript/`;
  # the layout emits the map as a literal `<script type="importmap">` and the
  # assets route serves each file under a content-hash prefix so caches are
  # immutable and a gem upgrade changes every URL.
  #
  # No importmap-rails, no asset pipeline: this is what keeps the gem on the
  # Woods floors (railties 6.0) and free of a Node toolchain.
  module Importmap
    ROOTS = [
      Pathname.new(File.expand_path('../../app/javascript', __dir__)),
      Pathname.new(File.expand_path('../../vendor/javascript', __dir__))
    ].freeze

    # Bare specifier => logical path under one of {ROOTS}. Third-party pins
    # are added as the milestones vendor them (turbo, stimulus, mermaid,
    # cytoscape, vis-timeline, highlight.js).
    PINS = {
      'woods_map' => 'woods_map/application.js'
    }.freeze

    module_function

    # Resolve a logical path to a file under one of the roots.
    #
    # @param logical_path [String]
    # @return [Pathname, nil] nil when the path escapes the roots or is absent
    def resolve(logical_path)
      return nil if logical_path.to_s.empty? || logical_path.include?("\0")

      ROOTS.each do |root|
        candidate = root.join(logical_path).cleanpath
        next unless candidate.to_s.start_with?("#{root}/") && candidate.file?

        return candidate
      end
      nil
    end

    # @param logical_path [String]
    # @return [String, nil] first 16 hex chars of the file's SHA-256, or nil
    def digest(logical_path)
      file = resolve(logical_path)
      file && Digest::SHA256.file(file.to_s).hexdigest[0, 16]
    end

    # Build the import map JSON for the layout.
    #
    # @param url_for [#call] maps (digest, logical_path) to a URL
    # @return [String] JSON for the `importmap` script tag
    def to_json(url_for:)
      imports = PINS.each_with_object({}) do |(name, path), map|
        digest = digest(path)
        next unless digest

        map[name] = url_for.call(digest, path)
      end
      JSON.generate(imports: imports)
    end
  end
end
