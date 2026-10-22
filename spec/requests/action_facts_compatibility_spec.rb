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
                                          freshness: { 'state' => 'unknown' })
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
end
