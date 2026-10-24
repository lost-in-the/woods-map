# frozen_string_literal: true

require 'cgi'

# The explorer's overlays (A-4, A-6; notes/graph-page.md): the flows the centre
# takes part in from Woods W-13 with the one ?flow= lays over the canvas, and
# the commits of the W-3 commit table that touched the units drawn.
RSpec.describe 'Graph overlays', type: :request do
  def page_for(path, params = {})
    get path, params: params
    expect(response).to have_http_status(:ok)
    html_response_document
  end

  context 'with a generation that publishes flows' do
    before do
      skip 'this Woods has no flow readers (W-13, woods#805)' unless WoodsMap::FlowIndex.readers?
      WoodsMap.configuration.index_dir = WoodsMap::FlowIndex.path
    end

    it 'lists the flows a unit takes part in, each keeping the view it lays itself over' do
      html = page_for('/woods/units/model/Micropost/graph', depth: '2')
      links = html.css('nav.rail ol.flows a')
      expect(links.map(&:text)).to eq(['MicropostsController#create'])
      query = CGI.parse(URI.parse(links.first['href']).query)
      expect(query).to include('flow' => ['MicropostsController#create'], 'depth' => ['2'])
    end

    it 'hands the canvas the drawn steps and lists every step with what reached it' do
      html = page_for('/woods/graph', centre: 'Micropost', type: 'model', flow: 'MicropostsController#create')
      payload = JSON.parse(html.at_css('[data-controller~=graph]')['data-graph-flow-value'])
      expect(payload['steps'].pluck('identifier')).to eq(%w[MicropostsController Micropost User])
      rows = html.css('table[aria-label="Steps of MicropostsController#create"] tbody tr')
      expect(rows.map { |row| row.css('td').last.text.strip })
        .to eq(['the entry point', 'code_reference, MicropostsController → Micropost', 'belongs_to, Micropost → User',
                'no graph edge from the step before'])
      expect(rows.last['class']).to include('nomatch')
    end

    it 'marks the selected flow in the rail and the legend, and keeps it through the filters' do
      html = page_for('/woods/graph', centre: 'Micropost', type: 'model', flow: 'MicropostsController#create')
      expect(html.at_css('nav.rail ol.flows a[aria-current=true]').text).to eq('MicropostsController#create')
      expect(html.css('.legend i.gflow').size).to eq(1)
      expect(html.at_css('nav.rail input[name=flow]')['value']).to eq('MicropostsController#create')
    end

    it 'keeps the flow on the depth and direction links and offers to clear it' do
      html = page_for('/woods/graph', centre: 'Micropost', type: 'model', flow: 'MicropostsController#create')
      depth = html.css('[aria-label=Depth] a').pluck('href')
      expect(depth).to all(include('flow=MicropostsController%23create'))
      expect(html.at_css('nav.rail a:contains("clear the flow")')['href']).not_to include('flow=')
    end

    it 'says when the generation does not list the flow asked for' do
      html = page_for('/woods/graph', centre: 'Micropost', type: 'model', flow: 'UsersController#nope')
      expect(html.at_css('[data-controller~=graph]')['data-graph-flow-value']).to be_nil
      expect(html.at_css('#graph-flow-title').parent.parent.text).to include('lists no flow')
    end
  end

  it 'names why a generation without flows lists none' do
    html = page_for('/woods/units/model/User/graph')
    text = html.at_css('nav.rail').text
    expect(text).to include(WoodsMap::FlowIndex.readers? ? 'publishes no flows' : 'woods#805')
  end

  it 'lists the commits that touched the units drawn and hands the canvas the window' do
    html = page_for('/woods/graph', centre: 'Micropost', type: 'model')
    commits = JSON.parse(html.at_css('[data-controller~=graph]')['data-graph-timeline-value'])
    expect(commits.last).to include('sha', 'date', 'message', 'units')
    rows = html.css('table[aria-label="Commits touching the units drawn"] tbody tr')
    expect(rows.map { |row| row['data-commit'].to_i }).to eq((0...commits.size).to_a.reverse)
    scrub = html.at_css('[data-graph-target=scrub]')
    expect([scrub['hidden'], scrub.css('input[type=range]').size]).to eq(['', 2])
  end
end
