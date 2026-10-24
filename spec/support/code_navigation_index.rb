# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'digest'

# A one-generation index for code navigation: reference spans of every kind
# and confidence (W-1), method selectors (W-6) and method tables (W-2), with
# a second caller so the callers panel has more than one row.
module CodeNavigationIndex
  POST_SOURCE = <<~RUBY
    class Post < ApplicationRecord
      belongs_to :author
      before_save :set_slug

      def self.publish_all
        NotifyJob.deliver_all(id)
        Notifier.deliver
        Helper.call
      end

      private

      def set_slug
        self.slug = title
      end
    end
  RUBY
  COMMENT_SOURCE = "class Comment < ApplicationRecord\n  def notify\n    Post.publish_all\n    " \
                   "NotifyJob.deliver_all(1)\n  end\nend\n"
  JOB_SOURCE = "class NotifyJob < ApplicationJob\n  def self.deliver_all(id)\n    perform_later(id)\n  end\nend\n"

  # @param position [Array(Integer, Integer, Integer)] line, byte column, byte length
  def self.span(position, target, type, **extra)
    line, column, length = position
    { 'line' => line, 'column' => column, 'length' => length, 'target' => target, 'target_type' => type,
      'kind' => 'constant', 'confidence' => 'verified' }.merge(extra.transform_keys(&:to_s)).compact
  end

  # @param lines [Range] first..last line of the definition
  def self.method(name, lines, owner, kind: 'instance', visibility: 'public')
    { 'name' => name, 'kind' => kind, 'line' => lines.first, 'end_line' => lines.last, 'visibility' => visibility,
      'owner' => owner }
  end

  POST_REFERENCES = [
    span([2, 13, 7], 'Author', 'model', kind: 'association'),
    span([3, 14, 9], 'Post', 'model', kind: 'callback_method', method: 'set_slug'),
    span([6, 4, 9], 'NotifyJob', 'job', method: 'deliver_all'),
    { 'line' => 7, 'column' => 4, 'length' => 8, 'kind' => 'constant', 'confidence' => 'ambiguous',
      'method' => 'deliver', 'candidates' => [{ 'target' => 'Admin::Notifier', 'target_type' => 'service' },
                                              { 'target' => 'Notifier', 'target_type' => 'lib' }] },
    span([8, 4, 6], 'Helper', 'poro', confidence: 'static', method: 'call')
  ].freeze

  def code_navigation_index(root)
    units = callers + [
      nav_unit('Author', 'model', 'app/models/author.rb'),
      nav_unit('Admin::Notifier', 'service', 'app/services/admin/notifier.rb'),
      nav_unit('Notifier', 'lib', 'lib/notifier.rb'),
      nav_unit('Helper', 'poro', 'app/models/helper.rb')
    ]
    Writer.write_navigation_generation(root, units)
  end

  # The units with source, spans and method tables.
  def callers
    [
      nav_unit('Post', 'model', 'app/models/post.rb', POST_SOURCE,
               'references' => POST_REFERENCES,
               'methods' => [CodeNavigationIndex.method('publish_all', 5..9, 'Post', kind: 'singleton'),
                             CodeNavigationIndex.method('tag_list', 20..22, 'Taggable'),
                             CodeNavigationIndex.method('set_slug', 13..15, 'Post', visibility: 'private')]),
      nav_unit('Comment', 'model', 'app/models/comment.rb', COMMENT_SOURCE,
               'references' => [CodeNavigationIndex.span([3, 4, 4], 'Post', 'model', method: 'publish_all'),
                                CodeNavigationIndex.span([4, 4, 9], 'NotifyJob', 'job', method: 'deliver_all')],
               'methods' => [CodeNavigationIndex.method('notify', 2..5, 'Comment')]),
      nav_unit('NotifyJob', 'job', 'app/jobs/notify_job.rb', JOB_SOURCE,
               'methods' => [CodeNavigationIndex.method('deliver_all', 2..4, 'NotifyJob', kind: 'singleton')]),
      nav_unit('Taggable', 'concern', 'app/models/concerns/taggable.rb',
               "module Taggable\n\n  def tag_list\n  end\nend\n",
               'methods' => [CodeNavigationIndex.method('tag_list', 3..4, 'Taggable')])
    ]
  end

  def nav_unit(identifier, type, path, source = "class #{identifier.split('::').last}\nend\n", metadata = {})
    { 'identifier' => identifier, 'type' => type, 'file_path' => path, 'source_code' => source,
      'metadata' => metadata, 'dependencies' => [], 'dependents' => [] }
  end

  # Point the engine at a fresh navigation index for the duration of each example.
  def self.included(group)
    group.before do
      code_navigation_index(code_navigation_root)
      WoodsMap.configuration.index_dir = code_navigation_root
      WoodsMap::FileTree.reset!
      WoodsMap::Callers.reset!
    end
    group.after do
      WoodsMap::FileTree.reset!
      WoodsMap::Callers.reset!
      FileUtils.remove_entry(code_navigation_root)
    end
  end

  def code_navigation_root
    @code_navigation_root ||= Pathname.new(Dir.mktmpdir('map-code-navigation'))
  end

  # Writes one published generation of the given units.
  module Writer
    module_function

    def write_navigation_generation(root, units)
      root.join('generation.json').write(JSON.generate('number' => 1, 'token' => 'nav1', 'payload' => 'payloads/gen-1'))
      payload = root.join('payloads/gen-1')
      groups = units.group_by { |unit| Woods::MCP::IndexReader::TYPE_TO_DIR.fetch(unit['type']) }
      groups.each { |directory, records| write_navigation_units(payload.join(directory), records) }
      payload.join('manifest.json').write(JSON.generate('total_units' => units.size,
                                                        'counts' => groups.transform_values(&:size)))
      nodes = units.to_h { |unit| [unit['identifier'], unit.slice('type', 'file_path')] }
      payload.join('dependency_graph.json').write(JSON.generate('nodes' => nodes, 'file_map' => {}))
    end

    def write_navigation_units(directory, units)
      FileUtils.mkdir_p(directory)
      directory.join('_index.json').write(JSON.generate(units.map { |unit| unit.slice('identifier', 'file_path') }))
      units.each do |unit|
        identifier = unit.fetch('identifier')
        base = identifier.gsub('::', '__').gsub(/[^a-zA-Z0-9_-]/, '_')
        directory.join("#{base}_#{Digest::SHA256.hexdigest(identifier)[0, 8]}.json").write(JSON.generate(unit))
      end
    end
  end
end
