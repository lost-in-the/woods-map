# frozen_string_literal: true

RSpec.describe 'Impact range', type: :request do
  let(:data) do
    { 'schema_version' => 1,
      'range' => { 'from' => { 'generation' => 4, 'manifest_checksum' => 'same-manifest' },
                   'to' => { 'generation' => 5, 'manifest_checksum' => 'same-manifest' } },
      'parameters' => { 'depth' => 2, 'types' => nil, 'via' => nil },
      'changed' => [{ 'identifier' => '<old>', 'type' => 'model', 'status' => 'removed', 'facets' => ['source'] },
                    { 'identifier' => '<old>', 'type' => 'service', 'status' => 'added' }],
      'affected' => %w[from to].map do |side|
        { 'identifier' => 'Shared', 'type' => 'controller', 'endpoint' => side,
          'generation' => side == 'from' ? 4 : 5, 'weight' => nil }
      end,
      'flows' => [{ 'entry_point' => 'Shared#show', 'endpoint' => 'to', 'generation' => 5,
                    'route' => { 'verb' => 'GET', 'path' => '/synthetic' },
                    'changed_steps' => [{ 'identifier' => '<old>', 'type' => 'service' }] }],
      'coverage' => { 'complete' => false, 'affected' => 'partial', 'tests' => 'not_computed' },
      'unknowns' => [{ 'kind' => 'node_budget', 'endpoint' => 'to', 'generation' => 5 }] }.freeze
  end

  it 'opens an accessible selector form without invoking a comparison' do
    allow(WoodsMap::ImpactRange).to receive(:new)
    get '/woods/impact', params: { mode: 'range' }
    expect(response.body).to include('for="range-from"', 'id="range-from"', 'Compare range')
    expect(WoodsMap::ImpactRange).not_to have_received(:new)
  end

  it 'renders authoritative endpoint context and escapes historical identities without current links' do
    allow(WoodsMap::ImpactRange).to receive(:new).and_return(instance_double(WoodsMap::ImpactRange,
                                                                             state: :available, data: data))
    get '/woods/impact', params: { from: 'gen:4', to: 'now' }
    expect(response.body).to include('&lt;old&gt;', 'same-manifest', 'not_computed', 'node_budget')
    expect(response.body).to include('Removed units belong to From', 'Unavailable', 'Unrestricted', '/synthetic')
    expect(response.body).not_to include('/woods/units/model/%3Cold%3E', '/woods/units/controller/Shared')
    expect(data['affected'].pluck('generation')).to eq([4, 5])
  end

  it 'does not interpret deferred empty sections as a conclusive zero' do
    empty = data.merge('changed' => [], 'affected' => [], 'flows' => [])
    allow(WoodsMap::ImpactRange).to receive(:new).and_return(instance_double(WoodsMap::ImpactRange,
                                                                             state: :available, data: empty))
    get '/woods/impact', params: { from: 'gen:4' }
    expect(response.body).to include('not a conclusive zero', 'not_computed', 'node_budget')
  end

  it 'renders invalid input locally without claiming the published index is missing' do
    allow(WoodsMap::ImpactRange).to receive(:new).and_return(instance_double(WoodsMap::ImpactRange,
                                                                             state: :invalid, message: 'Invalid range'))
    get '/woods/impact', params: { from: 'invalid' }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Invalid range')
    expect(response.body).not_to include('No published Woods index', 'Blast radius')
  end

  ['from[x]=1', 'from[]=gen%3A1', 'from=gen%3A1&to[x]=1', 'from=gen%3A1&to[]=now'].each do |query|
    it "rejects nonscalar selectors through Rails routing: #{query}" do
      allow(WoodsMap::ImpactRange).to receive(:backend).and_call_original
      get "/woods/impact?#{query}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('The range could not be resolved')
      expect(WoodsMap::ImpactRange).not_to have_received(:backend)
    end
  end
end
