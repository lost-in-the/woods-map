# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'digest'

# A one-generation index whose Caller links two models, for the hover cards.
module HoverCardIndex
  CALLER_SOURCE = "class Caller\n  Widget.call; Gadget.call\nend\n"
  GIT = { 'last_author' => 'Ada <Lovelace>', 'last_modified' => '2026-10-20T10:00:00Z', 'commit_count' => 12,
          'change_frequency' => 'hot' }.freeze
  PAGERANK = { 'Caller' => 0.1, 'Domain::Widget' => 0.4, 'Other' => 0.4, 'Gadget' => 0.05 }.freeze

  def hover_card_index(root)
    references = [['Domain::Widget', 2], ['Gadget', 15]].map do |target, column|
      { 'line' => 2, 'column' => column, 'length' => 6, 'target' => target, 'target_type' => 'model',
        'kind' => 'constant', 'confidence' => 'verified' }
    end
    units = [card_unit('Caller', source: CALLER_SOURCE, metadata: { 'references' => references }),
             card_unit('Domain::Widget', metadata: { 'git' => GIT }), card_unit('Gadget', path: nil)]
    write_card_generation(root, units)
  end

  def card_unit(identifier, source: '', metadata: {}, path: 'app/models/synthetic.rb')
    { 'identifier' => identifier, 'type' => 'model', 'file_path' => path,
      'source_code' => source, 'metadata' => metadata, 'dependencies' => [], 'dependents' => [] }
  end

  def write_card_generation(root, units)
    root.join('generation.json').write(JSON.generate('number' => 1, 'token' => 'cards1', 'payload' => 'payloads/gen-1'))
    payload = root.join('payloads/gen-1')
    write_card_units(payload.join('models'), units)
    payload.join('manifest.json').write(JSON.generate('total_units' => units.size))
    nodes = units.to_h { |unit| [unit['identifier'], unit.slice('type', 'file_path')] }
    nodes['Domain::Widget'].merge!('commit_count' => 12, 'change_frequency' => 'hot')
    payload.join('dependency_graph.json')
           .write(JSON.generate('nodes' => nodes, 'file_map' => {}, 'pagerank' => PAGERANK))
  end

  def write_card_units(directory, units)
    FileUtils.mkdir_p(directory)
    directory.join('_index.json').write(JSON.generate(units.map { |unit| unit.slice('identifier', 'file_path') }))
    units.each do |unit|
      identifier = unit.fetch('identifier')
      base = identifier.gsub('::', '__').gsub(/[^a-zA-Z0-9_-]/, '_')
      directory.join("#{base}_#{Digest::SHA256.hexdigest(identifier)[0, 8]}.json").write(JSON.generate(unit))
    end
  end

  # Point the engine at a fresh hover-card index for the duration of each example.
  def self.included(group)
    group.before do
      hover_card_index(hover_card_root)
      WoodsMap.configuration.index_dir = hover_card_root
      WoodsMap::FileTree.reset!
    end
    group.after do
      WoodsMap::FileTree.reset!
      FileUtils.remove_entry(hover_card_root)
    end
  end

  def hover_card_root
    @hover_card_root ||= Pathname.new(Dir.mktmpdir('map-hover-cards'))
  end
end
