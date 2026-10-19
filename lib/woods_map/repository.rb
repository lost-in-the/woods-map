# frozen_string_literal: true

require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/module/delegation'
require 'woods/published_index'

module WoodsMap
  # One pinned generation per request.
  #
  # Wraps {Woods::PublishedIndex} so controllers never touch payload paths. The
  # block form holds the shared manifest lock for the duration of the request's
  # reads and releases it on the way out, which is what keeps retention from
  # deleting a payload mid-render.
  class Repository
    # Raised when no published generation can be opened at the configured root.
    class Unavailable < StandardError; end

    # Open the configured index for one block.
    #
    # @param index_dir [Pathname, String] defaults to the configured root
    # @yieldparam repository [WoodsMap::Repository]
    # @return [Object] the block's value
    # @raise [Unavailable] when the index is missing or unreadable
    def self.open(index_dir = WoodsMap.configuration.index_path)
      Woods::PublishedIndex.open(index_dir) { |index| yield new(index) }
    rescue ArgumentError, Woods::PublishedIndex::CorruptPointerError, Errno::ENOENT => e
      raise Unavailable, "No published Woods index at #{index_dir}: #{e.message}"
    end

    # @param index [Woods::PublishedIndex]
    def initialize(index)
      @index = index
    end

    # @!method generation_number
    #   @return [Integer] the pinned generation number (0 for a flat index)
    # @!method manifest
    #   @return [Hash] the pinned manifest
    delegate :generation_number, :manifest, to: :@index

    # Facts the manifest records at the top level on current writers and under
    # `provenance` on some older ones.
    PROVENANCE_KEYS = %w[git_branch git_sha rails_version ruby_version woods_version].freeze

    # Published generation numbers under the index root, ascending. A flat
    # (pre-2.0) index reports `[0]`.
    #
    # @return [Array<Integer>]
    def generations
      numbers = Woods::PublishedIndex.available_generations(@index.index_dir)
      numbers.empty? ? [generation_number] : numbers
    end

    # What the bar shows on every page: the generation and the HEAD it was
    # extracted at.
    #
    # @return [Hash{String => Object}]
    def generation_facts
      { 'generation' => generation_number, 'extracted_at' => manifest['extracted_at'] }.merge(provenance_facts)
    end

    # Status facts for the home page and the status bar.
    #
    # @return [Hash{String => Object}]
    def status
      generation_facts.merge(manifest_facts).merge('generations' => generations)
    end

    # @param type [String, nil]
    # @return [Array<Hash>] unit index entries
    def units(type: nil)
      @index.units(type: type)
    end

    # @param identifier [String]
    # @param type [String, nil]
    # @return [Hash, nil]
    def unit(identifier, type: nil)
      @index.unit(identifier, type: type)
    end

    private

    def manifest_facts
      {
        'total_units' => manifest.fetch('total_units') { manifest['total'] },
        'counts' => manifest.fetch('counts', {})
      }
    end

    def provenance_facts
      provenance = manifest['provenance'] || {}
      PROVENANCE_KEYS.index_with { |key| manifest.fetch(key) { provenance[key] } }
    end
  end
end
