# frozen_string_literal: true

require_relative 'trail_index'

# The trail index plus Post's publish state machine with structured
# transition callbacks (woods#796) and Post's method table (W-2), for the
# Lifecycle tab's transitions table. Include TrailIndex beside it.
module StateMachineIndex
  CALLBACKS = [
    { 'kind' => 'before_transition', 'on' => ['publish'], 'from' => [], 'to' => [], 'method' => 'set_slug',
      'block' => false, 'side_effects' => { 'columns_written' => ['slug'], 'jobs_enqueued' => [] } },
    { 'kind' => 'after_transition', 'on' => ['publish'], 'from' => [], 'to' => [], 'method' => 'notify_subscribers',
      'block' => false, 'side_effects' => { 'columns_written' => [], 'jobs_enqueued' => ['NotifySubscribersJob'] } },
    { 'kind' => 'after_transition', 'on' => [], 'from' => [], 'to' => ['archived'], 'method' => nil, 'block' => true,
      'side_effects' => nil, 'unanalysed' => 'block' },
    { 'kind' => 'before_transition', 'on' => [], 'from' => [], 'to' => [], 'method' => 'audit', 'block' => false,
      'side_effects' => nil, 'unanalysed' => 'not defined in the model or its concerns', 'unresolved' => ['from'] }
  ].freeze

  def state_machine_index(root, structured: true)
    trail_index(root)
    payload = root.join('payloads/gen-1')
    add_unit(payload, 'state_machines', machine_unit(structured))
    add_post_methods(payload)
    add_machine_edge(payload)
  end

  def machine_unit(structured)
    events = [{ 'name' => 'publish', 'transitions' => [{ 'from' => 'draft', 'to' => 'published', 'guard' => nil }] },
              { 'name' => 'archive', 'transitions' => [{ 'from' => 'published', 'to' => 'archived', 'guard' => nil }] }]
    metadata = { 'gem_detected' => 'state_machines', 'states' => %w[draft published archived], 'events' => events,
                 'initial_state' => 'draft', 'model_name' => 'Post',
                 'callbacks' => ['after_transition on: :publish, do: :notify_subscribers'] }
    metadata['transition_callbacks'] = CALLBACKS if structured
    unit('Post::state_machine_state', 'state_machine', 'app/models/post.rb', '', metadata)
  end

  def add_post_methods(payload)
    path = Dir[payload.join('models/Post_*.json').to_s].first
    data = JSON.parse(File.read(path))
    data['metadata']['methods'] = [{ 'name' => 'set_slug', 'kind' => 'instance', 'owner' => 'Post', 'line' => 4 },
                                   { 'name' => 'notify_subscribers', 'kind' => 'instance', 'owner' => 'Post',
                                     'line' => 8 }]
    File.write(path, JSON.generate(data))
  end

  def add_machine_edge(payload)
    path = payload.join('dependency_graph.json')
    graph = JSON.parse(path.read)
    graph['nodes']['Post::state_machine_state'] = { 'type' => 'state_machine', 'file_path' => 'app/models/post.rb' }
    graph['edges']['Post::state_machine_state'] = [{ 'target' => 'Post', 'via' => 'state_machine' }]
    reverse = { 'source' => 'Post::state_machine_state', 'source_type' => 'state_machine', 'via' => 'state_machine' }
    (graph['reverse_via']['Post'] ||= []) << reverse
    path.write(JSON.generate(graph))
  end
end
