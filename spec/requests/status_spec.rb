# frozen_string_literal: true

RSpec.describe 'Status page', type: :request do
  it 'renders the pinned generation for a loopback request without a token' do
    get '/woods'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('gen <b class="bright">1</b>')
    expect(response.body).to include('1 of 1, 1 retained (1)')
    expect(response.body).to include('type="importmap"')
  end

  it 'puts the page in a main landmark under the bar' do
    get '/woods'
    expect(response.body).to include('<header class="bar">').and include('<main class="page-main">')
  end

  it 'links the token sheet by content hash' do
    get '/woods'
    digest = WoodsMap::Assets.digest(WoodsMap::Assets::TOKENS)
    expect(response.body).to include("/woods/assets/#{digest}/woods_map/tokens.css")
  end

  it 'explains a missing index with the first-run empty state instead of failing' do
    WoodsMap.configuration.index_dir = '/nonexistent/woods'
    get '/woods'
    expect(response).to have_http_status(:service_unavailable)
    expect(response.body).to include('No published index yet').and include('woods:extract')
    expect(response.body).to include('no index')
  end
end
