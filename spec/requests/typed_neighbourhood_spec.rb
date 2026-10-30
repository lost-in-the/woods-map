# frozen_string_literal: true

RSpec.describe 'Typed graph pages', type: :request do
  before do
    graph = {
      'nodes' => { 'Report' => { 'type' => 'factory' } }, 'edges' => { 'Report' => [] },
      'variants' => [{ 'identifier' => 'Report', 'type' => 'model', 'edges' => [
        { 'target' => 'Report', 'type' => 'factory', 'via' => 'code_reference' },
        { 'target' => 'BaseReport', 'type' => 'model', 'via' => 'inheritance' }
      ] }]
    }
    allow(Woods::MCP::IndexReader).to receive(:new).and_return(instance_double(Woods::MCP::IndexReader))
    repository = WoodsMap::Repository.new(synthetic_published_index)
    allow(repository).to receive_messages(graph: graph, graph_analysis: {}, file_map: {}, generation_number: 192,
                                          manifest: { 'total_units' => 2 }, generation_facts: { 'generation' => 192 },
                                          generation_key: ['synthetic-typed-graph', 192],
                                          freshness: { 'state' => 'unknown' })
    unit = { 'identifier' => 'Report', 'type' => 'model', 'source_code' => 'class Report; end', 'metadata' => {} }
    allow(repository).to receive(:unit).and_return(nil)
    allow(repository).to receive(:unit).with('Report', type: 'model').and_return(unit)
    allow(WoodsMap::Repository).to receive(:open).and_yield(repository)
  end

  it 'uses the route type and links a coexisting type even when its identifier matches the focus' do
    get '/woods/units/model/Report/graph'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('code_reference', 'href="/woods/units/factory/Report"')
    expect(response.body).to include('Report (model)', 'Report (factory)')
  end

  it 'offers an inheritance edge in the via filter under structure' do
    get '/woods/units/model/Report/graph'
    family = html_response_document.css('.grp.flush').find { |g| g.text == 'structure' }
    expect(family).not_to be_nil
    rows = family.xpath('following-sibling::*').take_while { |n| !n.matches?('.grp') }
    vias = rows.map { |n| n.at_css('input')&.[]('value') }
    expect(vias).to include('code_reference', 'inheritance')
  end

  it 'centres the full-page graph on the typed unit type= names, not the first unit with that identifier' do
    get '/woods/graph', params: { centre: 'Report', type: 'model' }
    model = html_response_document
    get '/woods/graph', params: { centre: 'Report', type: 'factory' }
    factory = html_response_document
    expect(model.at_css('.ident .sub').text).to start_with('model')
    expect(factory.at_css('.ident .sub').text).to start_with('factory')
    expect(model.at_css('[data-controller~=graph]')['data-graph-url-value']).to include('type=model')
    expect(factory.at_css('[data-controller~=graph]')['data-graph-url-value']).to include('type=factory')
  end
end
