# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'tmpdir'

module WoodsMap
  # The landscape fixture as a Packwerk application would publish it (Woods
  # #280): two packages, `.` and `packs/posts`, each unit's `package` on its
  # graph node, the declared `package_dependency` edge from `packs/posts` to
  # `.`, and the root's undeclared reach into `packs/posts` in
  # graph_analysis.json.
  module PackageIndex
    POSTS = %w[Micropost MicropostsController].freeze

    module_function

    # @return [String] the index root, written once per process and removed at exit
    def path
      @path ||= begin
        dir = Dir.mktmpdir('woods-map-packages')
        at_exit { FileUtils.remove_entry(dir) if File.directory?(dir) }
        FileUtils.cp_r(File.join(LandscapeIndex.path, '.'), dir)
        payload = File.join(dir, 'payloads', 'gen-1')
        LandscapeIndex.patch(File.join(payload, 'dependency_graph.json')) { |graph| package(graph) }
        LandscapeIndex.patch(File.join(payload, 'graph_analysis.json')) do |analysis|
          analysis.merge('undeclared_package_edges' => [
                           { 'from' => 'User', 'from_type' => 'model', 'to' => 'Micropost', 'to_type' => 'model',
                             'via' => 'has_many', 'from_package' => '.', 'to_package' => 'packs/posts' }
                         ])
        end
        dir
      end
    end

    def package(graph)
      graph['nodes'].each do |identifier, node|
        next if node['file_path'].to_s.empty?

        node['package'] = POSTS.include?(identifier) ? 'packs/posts' : '.'
      end
      graph['nodes']['packs/posts'] =
        { 'type' => 'package', 'file_path' => 'packs/posts/package.yml', 'namespace' => nil }
      graph['nodes']['.'] = { 'type' => 'package', 'file_path' => 'package.yml', 'namespace' => nil }
      graph['edges']['packs/posts'] = [{ 'target' => '.', 'via' => 'package_dependency' }]
      graph
    end
  end
end
