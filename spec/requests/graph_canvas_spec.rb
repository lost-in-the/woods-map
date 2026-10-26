# frozen_string_literal: true

# The Graph tab's Cytoscape canvas (M5): the server renders the hidden panel and the
# query the graph controller fetches; the flowchart and the list stay the page without
# JavaScript, and every list row names the edge the canvas draws.
RSpec.describe 'Graph tab canvas', type: :request do
  def page_for(path)
    get path
    html_response_document
  end

  it 'points the controller at the neighbourhood JSON for the same query, by identifier, type and depth only' do
    html = page_for('/woods/units/model/User/graph?depth=2&direction=dependents&types[]=model')
    body = html.at_css('[data-controller~=graph]')
    url = URI.parse(body['data-graph-url-value'])
    expect(url.path).to eq('/woods/graph/neighbourhood')
    expect(parse_query(url.query)).to eq('centre' => ['User'], 'type' => ['model'], 'depth' => ['2'],
                                         'direction' => ['dependents'], 'types[]' => ['model'])
    expect(body['data-graph-unit-url-value'])
      .to eq('/woods/units/__type__/__identifier__/graph?depth=2&direction=dependents')
    expect(body['data-graph-generation-value']).to match(/\A\d+\z/)
  end

  it 'renders the canvas hidden, named and focusable, with a status line for the selection' do
    panel = page_for('/woods/units/model/User/graph').at_css('[data-graph-target=panel]')
    canvas = panel.at_css('[data-graph-target=canvas]')
    expect(panel['hidden']).not_to be_nil
    expect(canvas.to_h).to include('tabindex' => '0', 'role' => 'application', 'aria-describedby' => 'graph-status')
    expect(canvas['aria-label']).to start_with('Neighbourhood of User at depth 1, both')
    expect(panel.at_css('#graph-status[role=status]')).not_to be_nil
  end

  it 'offers zoom buttons and a link to the typed list beside the canvas, and says how to pan and zoom' do
    panel = page_for('/woods/units/model/User/graph').at_css('[data-graph-target=panel]')
    expect(panel.css('button[data-action="graph#zoomIn"]').pluck('aria-label')).to eq(['Zoom in'])
    expect(panel.css('button[data-action="graph#zoomOut"]').pluck('aria-label')).to eq(['Zoom out'])
    expect(panel.at_css('a[href="#edge-list"]').text).to include('list')
    expect(panel.at_css('#graph-status').text).to include('Drag to pan')
  end

  it 'keeps the flowchart and the list as the page without JavaScript' do
    html = page_for('/woods/units/model/User/graph')
    fallback = html.at_css('#graph-flowchart[data-graph-target=fallback]')
    expect(fallback['hidden']).to be_nil
    expect(fallback.at_css('[data-controller~=diagram] pre').text).to start_with('flowchart LR')
    expect(html.at_css('[data-graph-target=positions]')['hidden']).not_to be_nil
  end

  it 'keys the legend swatches by unit type for the token tints' do
    swatches = page_for('/woods/units/model/User/graph').css('[data-graph-target=panel] .legend i.gsw')
    expect(swatches.pluck('data-gtype')).to include('model')
  end

  it 'gives each list row the id of the edge the JSON carries' do
    html = page_for('/woods/units/model/User/graph')
    rows = html.css('[data-graph-target=list] tbody tr[data-edge]').pluck('data-edge')
    get '/woods/graph/neighbourhood', params: { centre: 'User', type: 'model' }
    ids = response.parsed_body.dig('elements', 'edges').map { |edge| edge.dig('data', 'id') }
    expect(rows).not_to be_empty
    expect(rows).to match_array(ids)
  end
end
