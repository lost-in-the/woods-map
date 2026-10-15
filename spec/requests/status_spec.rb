# frozen_string_literal: true

RSpec.describe 'Status page', type: :request do
  it 'renders the pinned generation for a loopback request without a token' do
    get '/woods'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('generation 1')
    expect(response.body).to include('type="importmap"')
  end

  it 'explains a missing index instead of failing' do
    WoodsMap.configuration.index_dir = '/nonexistent/woods'
    get '/woods'
    expect(response).to have_http_status(:service_unavailable)
    expect(response.body).to include('woods:extract')
  end
end
