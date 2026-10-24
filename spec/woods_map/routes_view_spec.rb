# frozen_string_literal: true

RSpec.describe WoodsMap::RoutesView do
  subject(:view) { described_class.new(repository, controller) }

  let(:controller) do
    { 'identifier' => 'WidgetsController', 'type' => 'controller',
      'metadata' => {
        'actions' => %w[index show],
        'routes' => { 'index' => [{ 'verb' => 'GET', 'path' => '/widgets', 'name' => 'widgets', 'constraints' => {} }],
                      'archive' => [{ 'verb' => 'POST', 'path' => '/widgets/archive', 'name' => nil }] },
        'action_sources' => { 'index' => { 'owner' => 'WidgetsController', 'defined_in' => 'WidgetsController',
                                           'file' => 'app/controllers/widgets_controller.rb', 'line' => 3 },
                              'show' => { 'owner' => 'WidgetsController', 'defined_in' => 'ApplicationController',
                                          'file' => 'app/controllers/application_controller.rb', 'line' => 9 } },
        'inherited_gem_actions' => { 'export' => { 'owner' => 'Exportable::Actions' } }
      } }
  end
  let(:route_units) do
    { 'GET /widgets' => { 'metadata' => { 'line_number' => 4 } },
      'GET /widgets/export' => { 'metadata' => { 'http_method' => 'GET', 'path' => '/widgets/export',
                                                 'action' => 'export', 'route_name' => 'export_widgets',
                                                 'line_number' => 7 } },
      'POST /widgets/archive' => { 'metadata' => { 'line_number' => 5 } } }
  end
  let(:repository) do
    graph = { 'reverse_via' => { 'WidgetsController' => [
      { 'source' => 'GET /widgets', 'source_type' => 'route', 'via' => 'route_dispatch' },
      { 'source' => 'GET /widgets/export', 'source_type' => 'route', 'via' => 'route_dispatch' },
      { 'source' => 'widgets/index.html.erb', 'source_type' => 'view_template', 'via' => 'link_to' },
      { 'source' => 'WidgetsController', 'source_type' => 'controller', 'via' => 'redirect_to' },
      { 'source' => 'widgets/index.html.erb', 'source_type' => 'view_template', 'via' => 'view_render' }
    ] } }
    analysis = { 'unresolvable_routes' => [
      { 'route' => 'POST /widgets/archive', 'controller' => 'WidgetsController', 'action' => 'archive',
        'reason' => 'missing_action' },
      { 'route' => 'GET /other', 'controller' => 'OtherController', 'action' => 'x', 'reason' => 'missing_action' }
    ] }
    repo = instance_double(WoodsMap::Repository, graph: graph, graph_analysis: analysis)
    allow(repo).to receive(:unit) { |identifier, type: nil| type == 'route' ? route_units[identifier] : nil }
    repo
  end

  it 'joins declared routes to route units and adds dispatching routes the metadata omits' do
    expect(view.routes.map(&:identifier)).to eq(['GET /widgets', 'POST /widgets/archive', 'GET /widgets/export'])
    expect(view.routes.map(&:line)).to eq([4, 5, 7])
    expect(view.routes.first.helpers).to eq(%w[widgets_path widgets_url])
    expect(view.count).to eq(3)
  end

  it 'takes findings from graph analysis for this controller only' do
    expect(view.unresolvable.map(&:identifier)).to eq(['POST /widgets/archive'])
    expect(view.unresolvable.first.finding).to eq('missing_action')
  end

  it 'lists actions with their sources, inherited and gem-defined ones included' do
    actions = view.actions.index_by(&:name)
    expect(actions.keys).to eq(%w[index show export archive])
    expect(actions['show']).to be_inherited
    expect(actions['export']).to have_attributes(gem: true, owner: 'Exportable::Actions')
    expect(view.unrouted_actions.map(&:name)).to eq(%w[show])
  end

  it 'keeps only navigation edges as helper references, in mechanism order' do
    expect(view.references.map { |ref| [ref.source, ref.via] })
      .to eq([%w[widgets/index.html.erb link_to], %w[WidgetsController redirect_to]])
  end

  it 'names what the index cannot show' do
    expect(view.limits).to eq(['helper references name the controller, not the helper or action (woods#795)'])
  end
end
