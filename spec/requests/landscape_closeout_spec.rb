# frozen_string_literal: true

# M3 close-out (woods-map#5): the Landscape's Status tab, the Domains mindmap,
# the treemap's other sizes, and the Schema tab's class diagram.
RSpec.describe 'Landscape status, mindmap, treemap sizes and class diagram', type: :request do
  def page(path)
    get path
    expect(response).to have_http_status(:ok)
    html_response_document
  end

  context 'with the landscape fixture' do
    before { WoodsMap.configuration.index_dir = WoodsMap::LandscapeIndex.path }

    it 'lists what the generation publishes for the Landscape, and what it lacks' do
      rows = page('/woods/landscape/status').css('table[aria-label="Landscape data"] tbody tr')
                                            .to_h { |tr| [tr.at_css('td b').text, tr.css('td')[1].text.strip] }
      expect(rows).to include('container attribution' => include('published'),
                              'domain clusters' => include('published'),
                              'source sizes' => 'absent', 'external services' => 'absent')
    end

    it 'draws the domain clusters as a mindmap with its .mmd text' do
      texts = page('/woods/landscape/domains').css('[data-controller~=diagram] pre').map(&:text)
      expect(texts).to include(start_with('mindmap'))
      get '/woods/landscape/mindmap.mmd'
      expect(response.body).to start_with('mindmap').and include('Users')
    end
  end

  context 'with packages' do
    before { WoodsMap.configuration.index_dir = WoodsMap::PackageIndex.path }

    it 'sizes the treemap by unit count or PageRank on request' do
      units = page('/woods/landscape/hotspots?size=units')
      expect(units.at_css('[aria-label="Size the treemap by"] a[aria-current=true]').text).to eq('unit count')
      expect(units.at_css('table[aria-label="Unit count by block and type"]')).not_to be_nil
      get '/woods/landscape/treemap.mmd', params: { size: 'pagerank' }
      expect(response.body).to start_with('treemap-beta')
    end
  end

  it 'draws the model as a class diagram on the Schema tab, and serves its text' do
    document = page('/woods/units/model/User/schema')
    expect(document.css('[data-controller~=diagram] pre').map(&:text)).to include(start_with('classDiagram'))
    get '/woods/units/model/User/schema.mmd', params: { view: 'class' }
    expect(response.body).to start_with('classDiagram').and include('class User')
  end
end
