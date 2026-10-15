# frozen_string_literal: true

RSpec.describe 'Authentication', type: :request do
  let(:remote) { { 'REMOTE_ADDR' => '203.0.113.9' } }

  it 'refuses a non-loopback request while no token is configured' do
    get '/woods', env: remote
    expect(response).to have_http_status(:forbidden)
    expect(response.body).to include('config.token')
  end

  context 'with a token configured' do
    before { WoodsMap.configuration.token = 'secret-token' }

    it 'accepts a matching bearer header' do
      get '/woods', headers: { 'Authorization' => 'Bearer secret-token' }, env: remote
      expect(response).to have_http_status(:ok)
    end

    it 'redirects a browser without credentials to the session form' do
      get '/woods', env: remote
      expect(response).to redirect_to('/woods/session/new')
    end

    it 'answers 401 with a challenge for non-HTML clients' do
      get '/woods', headers: { 'Accept' => 'application/json' }, env: remote
      expect(response).to have_http_status(:unauthorized)
      expect(response.headers['WWW-Authenticate']).to include('Bearer')
    end

    it 'exchanges the token for a signed cookie and then serves pages' do
      post '/woods/session', params: { token: 'secret-token' }, env: remote
      expect(response.location).to match(%r{/woods/?\z})
      get '/woods', env: remote
      expect(response).to have_http_status(:ok)
    end

    it 'rejects a wrong token at the exchange' do
      post '/woods/session', params: { token: 'nope' }, env: remote
      expect(response).to have_http_status(:unauthorized)
    end

    it 'refuses a cross-origin write even with a valid token' do
      post '/woods/session', params: { token: 'secret-token' },
                             headers: { 'Origin' => 'https://evil.example', 'Authorization' => 'Bearer secret-token' },
                             env: remote
      expect(response).to have_http_status(:forbidden)
    end
  end

  it 'lets the host authorize hook refuse before any token check' do
    WoodsMap.configuration.authorize = ->(_request) { false }
    get '/woods'
    expect(response).to have_http_status(:forbidden)
  end
end
