# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'tmpdir'

module WoodsMap
  # Builds a published index of 300 models and their tables in a temporary
  # directory, for the ERD chunking checks (woods-map#5: "chunking verified
  # on a 300-model fixture"). Generated rather than checked in, so the
  # repository carries a page of Ruby instead of 600 JSON files.
  #
  # Layout: five namespaces of 50 models on `primary` and one of 50 on
  # `analytics`. Each model belongs_to the one before it in its namespace;
  # every third of those has no foreign key. Each namespace's first model
  # also belongs_to `Accounts::Model1` across namespaces, one model has a
  # polymorphic belongs_to, one association crosses databases, one foreign
  # key has no association, and two tables have no model.
  module LargeSchemaIndex
    NAMESPACES = { 'Accounts' => 'primary', 'Billing' => 'primary', 'Blog' => 'primary', 'Admin' => 'primary',
                   'Catalog' => 'primary', 'Analytics' => 'analytics' }.freeze
    PER_NAMESPACE = 50

    module_function

    # The index root, written once per process and removed at exit.
    #
    # @return [String]
    def path
      @path ||= begin
        dir = Dir.mktmpdir('woods-map-large-schema')
        at_exit { FileUtils.remove_entry(dir) if File.directory?(dir) }
        Writer.write(dir)
        dir
      end
    end

    # @return [Array<Hash>] model units
    def models
      NAMESPACES.flat_map do |namespace, database|
        (1..PER_NAMESPACE).map { |i| model(namespace, database, i) }
      end
    end

    def model(namespace, database, index)
      associations = []
      if index > 1
        associations << belongs_to("model#{index - 1}", "#{namespace}::Model#{index - 1}", "model#{index - 1}_id",
                                   database, database)
      end
      if index == 1 && namespace != 'Accounts'
        associations << belongs_to('owner', 'Accounts::Model1', 'owner_id', database, 'primary')
      end
      if index == 7
        associations << belongs_to('subject', nil, 'subject_id', database,
                                   database).merge('polymorphic' => true)
      end
      { 'type' => 'model', 'identifier' => "#{namespace}::Model#{index}", 'namespace' => namespace,
        'file_path' => "app/models/#{namespace.downcase}/model#{index}.rb", 'source_code' => '',
        'metadata' => { 'table_name' => table_name(namespace, index), 'database' => database,
                        'associations' => associations }, 'dependencies' => [] }
    end

    def belongs_to(name, target, key, from_db, to_db)
      { 'name' => name, 'type' => 'belongs_to', 'target' => target, 'foreign_key' => key, 'through' => nil,
        'polymorphic' => nil, 'from_db' => from_db, 'to_db' => to_db }
    end

    def table_name(namespace, index)
      "#{namespace.downcase}_model#{index}s"
    end

    # Tables carry a foreign key for each same-database belongs_to except every third one.
    def tables
      models.map { |m| table(m) } + %w[legacy_imports schema_audits].map { |name| unmodelled(name) }
    end

    def table(model)
      meta = model['metadata']
      columns = [{ 'name' => 'id', 'type' => 'integer' }] +
                meta['associations'].map { |a| { 'name' => a['foreign_key'], 'type' => 'integer' } } +
                [{ 'name' => 'name', 'type' => 'string' }]
      table_unit(meta['table_name'], meta['database'], model['identifier'], columns, foreign_keys(model))
    end

    # Every third chained belongs_to has no key; Catalog::Model10 has one key
    # no association declares, for the orphan-key finding.
    def foreign_keys(model)
      table = model.dig('metadata', 'table_name')
      keys = model.dig('metadata', 'associations').filter_map do |a|
        next if a['polymorphic'] || a['from_db'] != a['to_db'] || a['foreign_key'].delete_prefix('model').to_i % 3 == 2

        { 'from_table' => table, 'to_table' => target_table(a['target']), 'column' => a['foreign_key'] }
      end
      return keys unless model['identifier'] == 'Catalog::Model10'

      keys + [{ 'from_table' => table, 'to_table' => 'legacy_imports', 'column' => 'legacy_import_id' }]
    end

    def unmodelled(name)
      table_unit(name, 'primary', nil, [{ 'name' => 'id', 'type' => 'integer' }], [])
    end

    def table_unit(name, database, model, columns, fks)
      { 'type' => 'database_table', 'identifier' => "table:#{name}", 'file_path' => nil, 'namespace' => nil,
        'metadata' => { 'table_name' => name, 'database' => database, 'model' => model,
                        'models' => [model].compact, 'model_less' => model.nil?, 'primary_key' => 'id',
                        'columns' => columns, 'indexes' => [{ 'name' => "#{name}_name", 'columns' => ['name'],
                                                              'unique' => true }],
                        'foreign_keys' => fks }, 'dependencies' => [] }
    end

    def target_table(target)
      namespace, name = target.split('::')
      table_name(namespace, name.delete_prefix('Model').to_i)
    end

    # Writes the published layout: generation pointer, manifest, unit
    # directories with their indexes, graph and analysis.
    module Writer
      module_function

      def write(dir)
        payload = File.join(dir, 'payloads', 'gen-1')
        units = { 'models' => LargeSchemaIndex.models, 'database_tables' => LargeSchemaIndex.tables }
        units.each { |directory, list| write_units(File.join(payload, directory), list) }
        all = units.values.flatten
        write_json(File.join(payload, 'dependency_graph.json'), graph(all))
        write_json(File.join(payload, 'graph_analysis.json'), { 'unmodelled_tables' => [] })
        write_json(File.join(payload, 'manifest.json'),
                   { 'extracted_at' => '2026-10-18T00:00:00Z', 'woods_version' => '2.2.0.alpha',
                     'counts' => units.transform_values(&:size), 'total_units' => all.size, 'total_chunks' => 0,
                     'git_sha' => '0' * 40, 'git_branch' => 'main' })
        write_json(File.join(dir, 'generation.json'),
                   { 'number' => 1, 'token' => 'large0001', 'updated_at' => '2026-10-18T00:00:00Z', 'reason' => 'full',
                     'payload' => 'payloads/gen-1' })
      end

      def write_units(directory, list)
        FileUtils.mkdir_p(directory)
        index = list.map do |unit|
          id = unit['identifier']
          name = "#{id.gsub('::', '__').gsub(/[^a-zA-Z0-9_-]/, '_')}_#{Digest::SHA256.hexdigest(id)[0, 8]}.json"
          write_json(File.join(directory, name), unit.merge('dependents' => [], 'chunks' => []))
          { 'identifier' => id, 'file_path' => unit['file_path'], 'namespace' => unit['namespace'],
            'estimated_tokens' => 10, 'chunk_count' => 0 }
        end
        write_json(File.join(directory, '_index.json'), index)
      end

      def graph(units)
        nodes = units.to_h do |u|
          [u['identifier'], { 'type' => u['type'], 'file_path' => u['file_path'], 'namespace' => u['namespace'] }]
        end
        type_index = units.group_by { |u| u['type'] }.transform_values { |list| list.pluck('identifier') }
        { 'nodes' => nodes, 'edges' => nodes.transform_values { [] }, 'reverse' => {}, 'reverse_via' => {},
          'file_map' => {}, 'type_index' => type_index, 'pagerank' => {},
          'stats' => { 'node_count' => nodes.size, 'edge_count' => 0 } }
      end

      def write_json(path, data)
        File.write(path, JSON.generate(data))
      end
    end
  end
end
