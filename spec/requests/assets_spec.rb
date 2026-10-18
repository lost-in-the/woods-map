# frozen_string_literal: true

RSpec.describe 'Engine-served assets', type: :request do
  let(:digest) { WoodsMap::Assets.digest }

  it 'serves a pinned module under its content digest with immutable caching' do
    get "/woods/assets/#{digest}/woods_map/application.js"
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('text/javascript')
    expect(response.headers['Cache-Control']).to include('immutable')
  end

  it 'serves the token sheet as CSS under the set digest, without authentication' do
    get "/woods/assets/#{digest}/#{WoodsMap::Assets::TOKENS}", env: { 'REMOTE_ADDR' => '203.0.113.9' }
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('text/css')
    expect(response.body).to include('.wm{')
  end

  it 'serves a vendored font as font/woff2 and the font sheet beside it' do
    get "/woods/assets/#{digest}/fira-code/FiraCode-Regular.woff2"
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('font/woff2')
    get "/woods/assets/#{digest}/#{WoodsMap::Assets::FONTS}"
    expect(response.body).to include('url(../fira-code/FiraCode-Regular.woff2)')
  end

  it 'does not serve a licence or a readme from the roots' do
    get "/woods/assets/#{digest}/fira-code/LICENSE"
    expect(response).to have_http_status(:not_found)
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
