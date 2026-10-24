# frozen_string_literal: true

module ActionFactsFixture
  def action_entry(renders: [], assigns: [])
    { 'file' => 'app/controllers/widgets_controller.rb', 'line' => 2,
      'assigns' => assigns, 'params' => [], 'redirects' => [], 'renders' => renders, 'formats' => [] }
  end

  def action_owner(identifier: 'WidgetsController', actions: ['show'], facts: { 'show' => action_entry })
    { 'identifier' => identifier, 'type' => 'controller', 'file_path' => 'app/controllers/widgets_controller.rb',
      'source_code' => "class #{identifier}\n  def show; end\nend\n",
      'metadata' => { 'actions' => actions, 'action_facts' => facts }, 'dependencies' => [] }
  end

  def action_template(identifier: 'widgets/show.html.erb', ivars: [], dependencies: [])
    { 'identifier' => identifier, 'type' => 'view_template', 'file_path' => "app/views/#{identifier}",
      'metadata' => { 'instance_variables' => ivars }, 'dependencies' => dependencies }
  end

  def action_repository(units, edges: {})
    nodes = units.to_h { |unit| [unit['identifier'], unit.slice('identifier', 'type', 'file_path')] }
    graph = { 'nodes' => nodes, 'edges' => edges, 'type_index' => {}, 'reverse_via' => {} }
    units.each { |unit| (graph['type_index'][unit['type']] ||= []) << unit['identifier'] }
    action_reverse_edges(graph, nodes, edges)
    repository = instance_double(WoodsMap::Repository, graph: graph, graph_analysis: {}, graph_node: nil,
                                                       flow_entry_points: nil,
                                                       flows_state: :absent,
                                                       generation_key: ['action facts fixture', graph.object_id])
    allow(repository).to receive(:unit) do |identifier, type: nil|
      units.find { |unit| unit['identifier'] == identifier && (!type || unit['type'] == type) }
    end
    repository
  end

  def action_reverse_edges(graph, nodes, edges)
    edges.each do |source, dependencies|
      dependencies.each do |edge|
        (graph['reverse_via'][edge['target']] ||= []) <<
          { 'source' => source, 'source_type' => nodes.dig(source, 'type'), 'via' => edge['via'] }
      end
    end
  end

  def action_review(repository, focus)
    WoodsMap::ImpactReview.new(repository, WoodsMap::BlastRadius.new(repository, focus: focus))
  end

  def ivar_result(review)
    review.rules.find { |rule| rule.name == WoodsMap::UnassignedIvarRule::NAME }.result
  end
end
