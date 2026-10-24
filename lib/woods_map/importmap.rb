# frozen_string_literal: true

require 'json'
require_relative 'assets'

module WoodsMap
  # The engine's own import map. Pins name the vendored modules under
  # `vendor/javascript/` and the engine's own code under `app/javascript/`;
  # the layout emits the map as a literal `<script type="importmap">` and
  # {WoodsMap::Assets} serves each file under the set's content digest so
  # caches are immutable and a gem upgrade changes every URL.
  #
  # No importmap-rails, no asset pipeline: this is what keeps the gem on the
  # Woods floors (railties 6.0) and free of a Node toolchain.
  module Importmap
    # Bare specifier => logical path under one of {WoodsMap::Assets::ROOTS}.
    # Third-party pins are added as the milestones vendor them.
    PINS = {
      'woods_map' => 'woods_map/application.js',
      '@hotwired/stimulus' => 'stimulus.js',
      'pele' => 'pele.js',
      'cytoscape' => 'cytoscape.esm.min.mjs'
    }.freeze

    module_function

    # Build the import map JSON for the layout.
    #
    # @param url_for [#call] maps (digest, logical_path) to a URL
    # @return [String] JSON for the `importmap` script tag
    def to_json(url_for:)
      imports = PINS.each_with_object({}) do |(name, path), map|
        next unless Assets.resolve(path)

        map[name] = url_for.call(Assets.digest, path)
      end
      JSON.generate(imports: imports)
    end
  end
end
