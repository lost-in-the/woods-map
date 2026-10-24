# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'digest'
require 'json'

# Writes into a copy of the fixture's payload: units with their index entry
# and manifest count, graph nodes and edges, and a commit.
module TrailIndexFiles
  PAIR_SHA = 'a1b2c3d4e5f60718293a4b5c6d7e8f9012345678'

  def add_unit(payload, dir, unit)
    directory = payload.join(dir)
    index = directory.join('_index.json')
    entries = JSON.parse(index.read) << unit.slice('identifier', 'file_path').merge('namespace' => nil)
    index.write(JSON.generate(entries))
    count_unit(payload, dir, entries.size)
    base = unit['identifier'].gsub('::', '__').gsub(/[^a-zA-Z0-9_-]/, '_')
    directory.join("#{base}_#{Digest::SHA256.hexdigest(unit['identifier'])[0, 8]}.json").write(JSON.generate(unit))
  end

  def count_unit(payload, dir, count)
    path = payload.join('manifest.json')
    manifest = JSON.parse(path.read)
    manifest['counts'][dir] = count
    manifest['total_units'] += 1
    path.write(JSON.generate(manifest))
  end

  def add_graph(payload)
    path = payload.join('dependency_graph.json')
    graph = JSON.parse(path.read)
    graph['nodes'].merge!(
      'Post' => { 'type' => 'model', 'file_path' => 'app/models/post.rb' },
      'NotifySubscribersJob' => { 'type' => 'job', 'file_path' => 'app/jobs/notify_subscribers_job.rb' },
      'table:posts' => { 'type' => 'database_table', 'file_path' => 'db/schema.rb' }
    )
    edges = { 'Post' => [{ 'target' => 'User', 'via' => 'belongs_to' },
                         { 'target' => 'NotifySubscribersJob', 'via' => 'job_enqueue' }],
              'NotifySubscribersJob' => [{ 'target' => 'Post', 'via' => 'code_reference' },
                                         { 'target' => 'MailingListMailer', 'via' => 'code_reference' }] }
    graph['edges'].merge!(edges)
    add_reverse(graph, edges)
    graph['file_map'].merge!('app/models/post.rb' => ['Post'],
                             'app/jobs/notify_subscribers_job.rb' => ['NotifySubscribersJob'])
    path.write(JSON.generate(graph))
  end

  def add_reverse(graph, edges)
    edges.each do |source, list|
      list.each do |edge|
        reverse = { 'source' => source, 'source_type' => graph['nodes'][source]['type'], 'via' => edge['via'] }
        (graph['reverse_via'][edge['target']] ||= []) << reverse
      end
    end
  end

  def add_commit(payload)
    path = payload.join('git_commits.json')
    table = JSON.parse(path.read)
    files = %w[app/jobs/notify_subscribers_job.rb app/mailers/mailing_list_mailer.rb]
    table['commits'].unshift('sha' => PAIR_SHA, 'parents' => [], 'author' => 'Ada Lovelace',
                             'date' => '2026-10-17T10:00:00+00:00',
                             'message' => 'Mail followers in batches', 'description' => '',
                             'files' => files.map { |f| { 'path' => f, 'status' => 'modified' } }, 'files_omitted' => 0)
    files.each { |f| (table['paths'][f] ||= []).unshift(PAIR_SHA) }
    path.write(JSON.generate(table))
  end
end

# The fixture index plus the blog scenario's Post and NotifySubscribersJob
# (design-study scenario 2): Post's after_commit enqueues the job, which
# delivers MailingListMailer#new_post, whose HTML template reads an ivar the
# action never assigns. A commit in the table touches the job and the mailer.
module TrailIndex
  include TrailIndexFiles

  POST_SOURCE = <<~RUBY
    class Post < ApplicationRecord
      belongs_to :author, class_name: "User"

      def set_slug
        self.slug = title.parameterize
      end

      def notify_subscribers
        NotifySubscribersJob.perform_later(id)
      end
    end
  RUBY

  JOB_SOURCE = <<~RUBY
    class NotifySubscribersJob < ApplicationJob
      def perform(post_id)
        post = Post.find(post_id)
        if post.published?
          post.author.followers.find_each { |user| MailingListMailer.new_post(user, post).deliver_later }
        end
      end
    end
  RUBY

  def trail_index(root, resilience: true, commit_table: true)
    FileUtils.cp_r(File.join(FIXTURE_INDEX, '.'), root)
    payload = root.join('payloads/gen-1')
    add_unit(payload, 'models', post_unit)
    add_unit(payload, 'jobs', job_unit(resilience))
    add_unit(payload, 'database_tables', posts_table)
    add_graph(payload)
    commit_table ? add_commit(payload) : payload.join('git_commits.json').delete
  end

  def post_unit
    callbacks = [
      { 'type' => 'before_save', 'filter' => 'set_slug', 'kind' => 'before',
        'conditions' => { 'if' => [':title_changed?'] } },
      { 'type' => 'after_create', 'filter' => 'autosave_associated_records_for_author', 'kind' => 'after',
        'conditions' => {} },
      { 'type' => 'after_commit', 'filter' => 'notify_subscribers', 'kind' => 'after',
        'conditions' => { 'on' => ['create'] } }
    ]
    associations = [{ 'name' => 'author', 'type' => 'belongs_to', 'target' => 'User', 'foreign_key' => 'author_id' }]
    unit('Post', 'model', 'app/models/post.rb', POST_SOURCE,
         'callbacks' => callbacks, 'associations' => associations, 'table_name' => 'posts')
  end

  def job_unit(resilience)
    facts = if resilience
              { 'retry_on' => [], 'discard_on' => [], 'rescue_from' => [], 'around_perform' => [],
                'rescue_handlers' => [], 'resilience_source' => 'runtime' }
            else
              {}
            end
    unit('NotifySubscribersJob', 'job', 'app/jobs/notify_subscribers_job.rb', JOB_SOURCE, facts)
  end

  def posts_table
    columns = [{ 'name' => 'id', 'type' => 'integer' }, { 'name' => 'author_id', 'type' => 'integer' },
               { 'name' => 'title', 'type' => 'string' }]
    unit('table:posts', 'database_table', 'db/schema.rb', '',
         'table_name' => 'posts', 'database' => 'primary', 'model' => 'Post', 'models' => ['Post'],
         'primary_key' => 'id',
         'columns' => columns, 'indexes' => [], 'model_less' => false,
         'foreign_keys' => [{ 'column' => 'author_id', 'to_table' => 'users' }])
  end

  def unit(identifier, type, path, source, metadata)
    { 'type' => type, 'identifier' => identifier, 'file_path' => path, 'namespace' => nil, 'source_code' => source,
      'metadata' => metadata, 'dependencies' => [], 'dependents' => [] }
  end

  # Skip an example the bundled Woods cannot answer yet (woods#755), so the
  # suite stays green against Woods main until the flow additions land.
  def require_woods(*capabilities)
    missing = capabilities.reject { |name| WoodsMap::RepositoryFlows.capabilities.fetch(name) }
    skip "needs Woods #{missing.join(', ')} (woods#755)" if missing.any?
  end

  # Point the engine at a fresh trail index for each example.
  def self.included(group)
    group.before do
      trail_index(trail_root)
      WoodsMap.configuration.index_dir = trail_root
      WoodsMap::FileTree.reset!
      WoodsMap::RepositoryFlows.reset!
      WoodsMap::Erd.reset!
    end
    group.after do
      WoodsMap.configuration.index_dir = FIXTURE_INDEX
      WoodsMap::FileTree.reset!
      WoodsMap::RepositoryFlows.reset!
      WoodsMap::Erd.reset!
      FileUtils.remove_entry(trail_root)
    end
  end

  def trail_root
    @trail_root ||= Pathname.new(Dir.mktmpdir('map-trail'))
  end
end
