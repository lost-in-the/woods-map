# frozen_string_literal: true

require 'cgi'

# The full-screen graph (M5, notes/graph-page.md): a typed centre by identifier and
# type, the shared explorer, the blast radius on request, hubs without a centre.
RSpec.describe 'Full-screen graph', type: :request do
  def page_for(path, params = {})
    get path, params: params
    html_response_document
  end

  it 'offers the published hubs as centres when none is named' do
    html = page_for('/woods/graph')
    expect(response).to have_http_status(:ok)
    links = html.css('table[aria-label=Hubs] a').pluck('href')
    expect(links).not_to be_empty
    expect(links).to all(start_with('/woods/graph?centre='))
  end

  it 'says when the named centre is not in the generation' do
    html = page_for('/woods/graph', centre: 'NoSuchUnit', type: 'model')
    expect(html.at_css('.empty-state').text).to include('No unit named NoSuchUnit')
  end

  it 'draws the centre with the explorer, re-centring the page from the canvas' do
    body = page_for('/woods/graph', centre: 'User', type: 'model',
                                    depth: 2).at_css('.graph-page[data-controller~=graph]')
    expect(CGI.parse(URI.parse(body['data-graph-url-value']).query))
      .to include('centre' => ['User'], 'type' => ['model'], 'depth' => ['2'])
    expect(body['data-graph-unit-url-value']).to start_with('/woods/graph?').and include('centre=__identifier__')
    expect(body['data-graph-cache-value']).to match(/\A\d+\|model\|User\|2\|both\|\|\z/)
  end

  it 'tints the blast radius of a change to the centre only when asked' do
    plain = page_for('/woods/graph', centre: 'User', type: 'model').at_css('[data-controller~=graph]')
    expect(plain['data-graph-blast-value']).to be_nil
    tinted = page_for('/woods/graph', centre: 'User', type: 'model', blast: '1').at_css('[data-controller~=graph]')
    expect(JSON.parse(tinted['data-graph-blast-value'])).to all(include('identifier', 'type', 'distance'))
    expect(html_response_document.css('.legend i.gblast').size).to eq(2)
  end
end
