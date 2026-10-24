# frozen_string_literal: true

require_relative '../support/action_facts_fixture'

RSpec.describe 'Action facts coverage pages', type: :request do
  include ActionFactsFixture

  def serve_actions(owner, templates = [])
    units = [owner] + templates
    repository = action_repository(units)
    allow(repository).to receive_messages(generation_number: 91, manifest: { 'total_units' => units.size },
                                          generation_key: ['synthetic-actions', 91], file_owner: nil,
                                          generation_facts: { 'generation' => 91 }, file_map: {},
                                          freshness: { 'state' => 'unknown' }, flow_failures: [])
    allow(WoodsMap::Repository).to receive(:open).and_yield(repository)
    repository
  end

  it 'shows missing named templates and incomplete coverage without certifying zero flags' do
    serve_actions(action_owner(facts: { 'show' => action_entry(renders: [{ 'template' => 'widgets/missing' }]) }))
    get '/woods/units/controller/WidgetsController/passage?action_name=show'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('widgets/missing', 'not in the index', 'Flag coverage is incomplete')
    expect(response.body).not_to include('none: every instance variable', 'unassigned</span><span>none')
  end

  it 'keeps old-index actions available and says their facts are unavailable' do
    owner = action_owner(facts: nil)
    serve_actions(owner)
    get '/woods/units/controller/WidgetsController/passage?action_name=show'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('WidgetsController#show', 'No flag can be raised yet')
  end

  it 'reports known-empty covered actions separately from missing bodies on Impact' do
    serve_actions(action_owner(actions: %w[show external]))
    get '/woods/impact', params: { focus: 'WidgetsController', lens: 'risks' }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('0 findings; incomplete: 1 action, 0 templates')
  end

  it 'labels lexical mentions as notes and never claims a nil runtime value' do
    template = action_template(ivars: ['@preferences', '@post', '@user'])
    assigns = %w[@post @user].map { |ivar| { 'ivar' => ivar, 'method' => 'show' } }
    owner = action_owner(facts: { 'show' => action_entry(renders: [{ 'template' => 'widgets/show' }],
                                                         assigns: assigns) })
    serve_actions(owner, [template])
    get '/woods/units/controller/WidgetsController/passage?action_name=show'
    expect(response.body).to include('@preferences</span>, no recorded assignment', 'Template mentions are lexical')
    expect(response.body).not_to include('@post</span>, no recorded assignment', '@user</span>, no recorded assignment')
    expect(response.body).not_to include('It renders nil', 'never assigned')
  end

  def serve_unresolved
    template = action_template
    template['metadata']['unresolved_partials'] = [{ 'kind' => 'interpolation', 'name' => 'shared/#{variant}' }] # rubocop:disable Lint/InterpolationCheck
    renders = [{ 'template' => 'widgets/show' },
               { 'object' => 'params[:template]', 'line' => 2, 'method' => 'show',
                 'file' => 'app/controllers/widgets_controller.rb' }]
    serve_actions(action_owner(facts: { 'show' => action_entry(renders: renders) }), [template])
  end

  it 'names a dynamic render target and an unresolved partial in the passage coverage note (#47)' do
    serve_unresolved
    get '/woods/units/controller/WidgetsController/passage?action_name=show'
    expect(response.body).to include('Flags 0, incomplete', 'Flag coverage is incomplete',
                                     'render target <code>params[:template]</code> in WidgetsController#show',
                                     'partial <code>shared/#{variant}</code> in widgets/show.html.erb, interpolation') # rubocop:disable Lint/InterpolationCheck
    expect(response.body).not_to include('none in available facts')
  end

  it 'reports a dynamic render target and an unresolved partial as incomplete on Impact (#47)' do
    serve_unresolved
    get '/woods/impact', params: { focus: 'WidgetsController', lens: 'risks' }
    expect(response.body).to include('0 findings; incomplete: 0 actions, 0 templates, 1 dynamic render target, ' \
                                     '1 unresolved partial')
    get '/woods/impact', params: { focus: 'WidgetsController', lens: 'unknown' }
    expect(response.body).to include('dynamic render', 'render params[:template]', 'unresolved partial')
  end

  def serve_b18_flags
    model = { 'identifier' => 'Widget', 'type' => 'model', 'file_path' => 'app/models/widget.rb', 'dependencies' => [],
              'metadata' => { 'column_names' => %w[id name], 'attribute_writers' => %w[id name] } }
    entry = action_entry(renders: [{ 'template' => 'widgets/show' }])
    entry['params'] = [{ 'key' => 'widget', 'permitted' => true, 'via' => 'widget_params', 'method' => 'show' }]
    owner = action_owner(facts: { 'show' => entry })
    owner['metadata']['permitted_params'] = { 'widget_params' => { 'model' => 'widget',
                                                                   'permitted' => %w[name nickname] } }
    page = action_template
    page['metadata']['partial_renders'] = [{ 'partial' => 'widgets/card', 'target' => 'widgets/_card.html.erb',
                                             'locals' => %w[widget size], 'dynamic_locals' => false, 'line' => 3 }]
    page['dependencies'] = [{ 'via' => 'render', 'target' => 'widgets/_card.html.erb' }]
    card = action_template(identifier: 'widgets/_card.html.erb')
    card['metadata'].merge!('locals_read' => ['widget'], 'locals_read_dynamic' => false, 'partial_renders' => [])
    serve_actions(owner, [page, card, model])
  end

  it 'raises the permitted-param and partial-local flags from published writers and locals (B-18)' do
    serve_b18_flags
    get '/woods/units/controller/WidgetsController/passage?action_name=show'
    expect(response.body).to include('Flags 2', 'no attribute: <span class="iv bad">nickname</span>',
                                     '<span class="iv bad">nickname</span> is permitted for',
                                     '<span class="iv bad">size</span> is passed to',
                                     'reads <span class="iv">widget</span>')
    expect(response.body).not_to include('Unverified, not flagged', 'Partial locals are not checked', 'woods#797')
  end

  it 'raises the permitted-param flag only on actions that read the params method' do
    repository = serve_b18_flags
    get '/woods/units/controller/WidgetsController/passage?action_name=show'
    expect(response.body).to include('is permitted for')
    repository.unit('WidgetsController', type: 'controller')['metadata']['action_facts']['show']['params'] = []
    get '/woods/units/controller/WidgetsController/passage?action_name=show'
    expect(response.body).not_to include('is permitted for', 'no attribute: <span class="iv bad">')
    expect(response.body).to include('no attribute: <span class="iv">nickname</span>')
  end
end
