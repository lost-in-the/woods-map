# frozen_string_literal: true

RSpec.describe 'Typed graph pages', type: :request do
  before do
    graph = {
      'nodes' => { 'Report' => { 'type' => 'factory' } }, 'edges' => { 'Report' => [] },
      'variants' => [{ 'identifier' => 'Report', 'type' => 'model', 'edges' => [
        { 'target' => 'Report', 'type' => 'factory', 'via' => 'code_reference' }
      ] }]
    }
    allow(Woods::MCP::IndexReader).to receive(:new).and_return(instance_double(Woods::MCP::IndexReader))
    repository = WoodsMap::Repository.new(instance_double(Woods::PublishedIndex,
                                                          payload_dir: Pathname.new('/synthetic/index')))
    allow(repository).to receive_messages(graph: graph, graph_analysis: {}, file_map: {}, generation_number: 192,
                                          manifest: { 'total_units' => 2 }, generation_facts: { 'generation' => 192 },
                                          generation_key: ['synthetic-typed-graph', 192],
                                          freshness: { 'state' => 'unknown' })
    unit = { 'identifier' => 'Report', 'type' => 'model', 'source_code' => 'class Report; end', 'metadata' => {} }
    allow(repository).to receive(:unit).with('Report', type: 'model').and_return(unit)
    allow(WoodsMap::Repository).to receive(:open).and_yield(repository)
  end

  it 'uses the route type and links a coexisting type even when its identifier matches the focus' do
    get '/woods/units/model/Report/graph'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('code_reference', 'href="/woods/units/factory/Report"')
    expect(response.body).to include('Report (model)', 'Report (factory)')
  end
end
