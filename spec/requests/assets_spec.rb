# frozen_string_literal: true

RSpec.describe 'Engine-served assets', type: :request do
  let(:digest) { WoodsMap::Importmap.digest('woods_map/application.js') }

  it 'serves a pinned module under its content digest with immutable caching' do
    get "/woods/assets/#{digest}/woods_map/application.js"
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('text/javascript')
    expect(response.headers['Cache-Control']).to include('immutable')
  end

  it 'returns 404 for a stale digest' do
    get '/woods/assets/0000000000000000/woods_map/application.js'
    expect(response).to have_http_status(:not_found)
  end

  it 'returns 404 for a path outside the engine roots' do
    get "/woods/assets/#{digest}/../../lib/woods_map.rb"
    expect(response).to have_http_status(:not_found)
  end
end
