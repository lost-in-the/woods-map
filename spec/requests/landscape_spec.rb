# frozen_string_literal: true

RSpec.describe 'Landscape', type: :request do
  context 'with container attribution' do
    before do
      WoodsMap.configuration.index_dir = WoodsMap::LandscapeIndex.path
      WoodsMap.configuration.system_name = 'Blog'
    end

    it 'draws the containers, the diagram and the relationships' do
      get '/woods/landscape'
      document = html_response_document
      expect(response).to have_http_status(:ok)
      expect(document.css('.c4box b').map(&:text)).to include('Web process', 'Job runner', 'Primary database',
                                                              'Mail delivery')
      expect(document.at_css('[data-controller~=diagram] pre').text).to start_with('flowchart LR')
      expect(document.at_css('table[aria-label=Relationships]')).not_to be_nil
    end

    it 'links each export to its plain-text URL' do
      get '/woods/landscape'
      hrefs = html_response_document.css('a[data-export]').pluck('href')
      expect(hrefs).to eq(%w[/woods/landscape.mmd /woods/landscape.dsl /woods/landscape.c4])
    end

    it 'gives the container diagram one copy tool and one .mmd link, the panel\'s own' do
      get '/woods/landscape'
      tools = html_response_document.at_css('.dia .dh .tools')
      expect(tools.css('[data-controller="copy"]').size).to eq(1)
      expect(tools.css('a[data-mermaid-url]').pluck('href')).to eq(['/woods/landscape.mmd'])
    end

    it 'serves the container diagram as Mermaid, Structurizr DSL and LikeC4 text' do
      { 'mmd' => 'flowchart LR', 'dsl' => 'workspace "Blog"', 'c4' => 'specification {' }.each do |ext, start|
        get "/woods/landscape.#{ext}"
        expect(response.media_type).to eq('text/plain')
        expect(response.body).to start_with(start).and end_with("\n")
        expect(response.headers['Content-Disposition']).to include("blog-containers.#{ext}")
      end
    end

    it 'lists the published domain clusters and opens the graph grouped by them' do
      get '/woods/landscape/domains'
      table = html_response_document.at_css('table[aria-label="Domain clusters"]')
      expect(table.text).to include('Users', 'User')
      expect(table.css('a').pluck('href')).to include(a_string_including('/woods/graph?centre=User', 'group=clusters'))
    end

    it 'gives the graph page the cluster of each member for its clusters layout' do
      get '/woods/graph', params: { centre: 'User', type: 'model', group: 'clusters' }
      body = html_response_document.at_css('[data-controller~=graph]')
      expect(JSON.parse(body['data-graph-clusters-value'])).to include(%w[User model Users])
      expect(body['data-graph-mode-value']).to eq('clusters')
    end
  end

  context 'without container attribution' do
    it 'says what the containers need and still serves the hotspots' do
      get '/woods/landscape'
      expect(html_response_document.at_css('.banner').text).to include('No container attribution')
      get '/woods/landscape/hotspots'
      expect(response).to have_http_status(:ok)
      expect(html_response_document.at_css('table[aria-label="Structural risk"]')).not_to be_nil
    end

    it 'answers 422 for the exports' do
      get '/woods/landscape.dsl'
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('W-9')
    end
  end
end
