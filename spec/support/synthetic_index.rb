# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'digest'

module WoodsMap
  # A one-generation published index written from unit hashes, for request
  # specs that need identifiers the shared fixture does not have. Units are
  # given by payload directory; each needs identifier, type and file_path.
  module SyntheticIndex
    # @param root [Pathname]
    # @param units [Hash{String => Array<Hash>}] payload directory => units
    # @return [Pathname] the index root
    def write_synthetic_index(root, units)
      root.join('generation.json').write(JSON.generate('number' => 1, 'token' => 'syn1', 'payload' => 'payloads/gen-1'))
      payload = root.join('payloads/gen-1')
      units.each { |directory, list| write_synthetic_units(payload.join(directory), list) }
      all = units.values.flatten
      payload.join('manifest.json').write(JSON.generate('total_units' => all.size))
      payload.join('dependency_graph.json').write(JSON.generate(synthetic_graph(all)))
      root
    end

    private

    def synthetic_graph(units)
      { 'nodes' => units.to_h { |unit| [unit['identifier'], unit.slice('type', 'file_path')] },
        'file_map' => units.select { |unit| unit['file_path'] }.group_by { |unit| unit['file_path'] }
                           .transform_values { |list| list.map { |unit| unit['identifier'] } } }
    end

    def write_synthetic_units(dir, units)
      FileUtils.mkdir_p(dir)
      dir.join('_index.json').write(JSON.generate(units.map { |unit| unit.slice('identifier', 'file_path') }))
      units.each do |unit|
        digest = Digest::SHA256.hexdigest(unit['identifier'])[0, 8]
        name = "#{unit['identifier'].gsub(/[^a-zA-Z0-9_-]/, '_')}_#{digest}.json"
        full = { 'metadata' => {}, 'dependencies' => [], 'dependents' => [], 'source_code' => '' }.merge(unit)
        dir.join(name).write(JSON.generate(full))
      end
    end
  end
end
