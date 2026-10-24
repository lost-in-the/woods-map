# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'tmpdir'

module WoodsMap
  # The fixture index as a Woods with container attribution (W-9) and
  # published domain clusters (woods#799) would write it: every node gains
  # its `container`, graph_analysis.json gains `domain_clusters`, and a
  # BehavioralProfile configuration unit is added. Built in a temporary
  # directory so the shared fixture stays as the older Woods wrote it.
  module LandscapeIndex
    KINDS = { 'controller' => 'web', 'view_template' => 'web', 'route' => 'web', 'job' => 'jobs', 'mailer' => 'jobs',
              'model' => 'database', 'database_table' => 'database' }.freeze

    PROFILE = {
      'type' => 'configuration', 'identifier' => 'BehavioralProfile', 'file_path' => nil, 'namespace' => nil,
      'source_code' => '', 'dependencies' => [], 'dependents' => [], 'chunks' => [],
      'metadata' => { 'config_type' => 'behavioral_profile', 'rails_version' => '8.0.0',
                      'database' => { 'adapter' => 'postgresql' },
                      'background_processing' => { 'adapter' => 'solid_queue' },
                      'caching' => { 'store' => 'solid_cache_store' }, 'email' => { 'delivery_method' => 'smtp' },
                      'frameworks_active' => { 'active_storage' => true }, 'behavior_flags' => { 'api_only' => false } }
    }.freeze

    module_function

    # @return [String] the index root, written once per process and removed at exit
    def path
      @path ||= begin
        dir = Dir.mktmpdir('woods-map-landscape')
        at_exit { FileUtils.remove_entry(dir) if File.directory?(dir) }
        FileUtils.cp_r(File.join(FIXTURE_INDEX, '.'), dir)
        payload = File.join(dir, 'payloads', 'gen-1')
        patch(File.join(payload, 'dependency_graph.json')) { |graph| attribute(graph) }
        patch(File.join(payload, 'graph_analysis.json')) { |analysis| cluster(analysis) }
        write_profile(payload)
        dir
      end
    end

    def attribute(graph)
      graph['nodes'].each_value do |node|
        kind = KINDS[node['type']]
        node['container'] = kind if kind
      end
      graph
    end

    def cluster(analysis)
      analysis.merge(
        'domain_clusters' => [{ 'name' => 'Users', 'hub' => 'User', 'members' => %w[User UsersController],
                                'typed_members' => [{ 'identifier' => 'User', 'type' => 'model' },
                                                    { 'identifier' => 'UsersController', 'type' => 'controller' }],
                                'member_count' => 2, 'entry_points' => ['UsersController'], 'boundary_edges' => [],
                                'types' => { 'model' => 1, 'controller' => 1 } }]
      )
    end

    def write_profile(payload)
      directory = File.join(payload, 'configurations')
      FileUtils.mkdir_p(directory)
      name = "BehavioralProfile_#{Digest::SHA256.hexdigest('BehavioralProfile')[0, 8]}.json"
      File.write(File.join(directory, name), JSON.generate(PROFILE))
      File.write(File.join(directory, '_index.json'),
                 JSON.generate([{ 'identifier' => 'BehavioralProfile', 'file_path' => nil, 'namespace' => nil,
                                  'estimated_tokens' => 10, 'chunk_count' => 0 }]))
      count_profile(payload)
    end

    def count_profile(payload)
      patch(File.join(payload, 'manifest.json')) do |manifest|
        manifest['counts'] = manifest['counts'].merge('configurations' => 1)
        manifest.merge('total_units' => manifest['total_units'] + 1)
      end
      patch(File.join(payload, 'dependency_graph.json')) do |graph|
        graph['nodes']['BehavioralProfile'] = { 'type' => 'configuration', 'file_path' => nil, 'namespace' => nil }
        graph['type_index']['configuration'] = ['BehavioralProfile'] if graph['type_index']
        graph
      end
    end

    def patch(file)
      File.write(file, JSON.generate(yield(JSON.parse(File.read(file)))))
    end
  end
end
