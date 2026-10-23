# frozen_string_literal: true

RSpec.describe 'Neighbourhood JSON', type: :request do
  let(:path) { '/woods/graph/neighbourhood' }
  let(:query) { { centre: 'User', type: 'model' } }

  it 'returns typed Cytoscape elements and pinned provenance' do
    get path, params: query
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('application/json')
    expect(response.parsed_body).to include('schema_version' => 1, 'query' => hash_including('depth' => 1))
    expect(response.parsed_body['provenance']).to include('generation', 'git_sha', 'sources')
  end

  it 'keeps the focus and reports omitted nodes and edges at the response boundary' do
    get path, params: query.merge(node_limit: 1)
    json = response.parsed_body
    expect(json.dig('elements', 'nodes').map { |n| n['data']['identifier'] }).to eq(['User'])
    expect(json.dig('elements', 'edges')).to all(satisfy { |e| e['data']['source'] == e['data']['target'] })
    expect(json['truncation']).to include('truncated' => true, 'omitted_nodes' => be_positive,
                                          'omitted_edges' => be_positive)
    expect(json['truncation']['boundaries']).not_to be_empty
  end

  it 'uses the same traversal and filters as the HTML graph tab' do
    get path, params: query.merge(depth: 2, direction: 'dependencies', types: ['model'], via: ['has_many'])
    edges = response.parsed_body.dig('elements', 'edges').pluck('data')
    expected = nil
    WoodsMap::Repository.open do |repository|
      expected = WoodsMap::Neighbourhood.new(repository, 'User', type: 'model', direction: 'dependencies', depth: 2,
                                                                 filters: { types: ['model'], via: ['has_many'] }).edges
    end
    expect(edges.size).to eq(expected.size)
    expect(edges.pluck('via').uniq).to eq(['has_many'])
  end

  it 'works under a different engine mount' do
    get '/catalog/map/graph/neighbourhood', params: query
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['query']).to include('centre' => 'User', 'type' => 'model')
  end

  [{}, { centre: 'User' }, { centre: ['User'], type: 'model' }, { depth: 'bogus' }, { depth: 3 },
   { direction: 'sideways' }, { types: 'model' }, { via: { name: 'has_many' } }, { node_limit: 0 },
   { node_limit: 301 }, { edge_limit: 1001 }].each do |invalid|
    it "rejects invalid query #{invalid.inspect} as JSON" do
      params = invalid.key?(:centre) || invalid.empty? ? invalid : query.merge(invalid)
      get path, params: params
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to include('error' => 'invalid_query')
    end
  end

  it 'returns JSON for a missing typed centre' do
    get path, params: query.merge(type: 'job')
    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body).to include('error' => 'unit_not_found')
  end

  it 'authenticates before opening the index, even without an Accept header' do
    WoodsMap.configuration.token = 'test-token'
    allow(WoodsMap::Repository).to receive(:open)
    get path, params: query
    expect(response).to have_http_status(:unauthorized)
    expect(WoodsMap::Repository).not_to have_received(:open)
  end

  it 'refuses the host hook before reading the index' do
    WoodsMap.configuration.authorize = ->(_request) { false }
    allow(WoodsMap::Repository).to receive(:open)
    get path, params: query
    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body).to eq('error' => 'forbidden')
    expect(WoodsMap::Repository).not_to have_received(:open)
  end

  it 'keeps bearer authorization and no-store responses available to JSON clients' do
    WoodsMap.configuration.token = 'test-token'
    get path, params: query, headers: { 'Authorization' => 'Bearer test-token' }
    expect(response).to have_http_status(:ok)
    expect(response.headers['Cache-Control']).to include('no-store')
  end

  it 'reports an unavailable index as JSON without leaking its path' do
    WoodsMap.configuration.index_dir = '/missing/private/index'
    get path, params: query
    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body).to eq('error' => 'index_unavailable')
  end
end
