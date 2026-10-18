# frozen_string_literal: true

RSpec.describe 'Authentication', type: :request do
  let(:remote) { { 'REMOTE_ADDR' => '203.0.113.9' } }

  describe 'a non-loopback request while no token is configured' do
    before { get '/woods', env: remote }

    it 'is refused with the 403 panel, without the frame' do
      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include('<h1 class="t2">Woods Map refused the request</h1>')
      expect(response.body).to include('WOODS_MAP_TOKEN').and include('config.authorize')
      expect(response.body).not_to include('class="bar"')
    end

    it 'leaks nothing from the index' do
      expect(response.body).not_to include('gen ')
      expect(response.body).not_to include('Post')
      expect(response.body).not_to include(FIXTURE_INDEX)
    end
  end

  it 'refuses every request, loopback included, when require_token is set without a token' do
    WoodsMap.configuration.require_token = true
    get '/woods'
    expect(response).to have_http_status(:forbidden)
  end

  it 'refuses the session form while no token is configured' do
    get '/woods/session/new', env: remote
    expect(response).to have_http_status(:forbidden)
    expect(response.body).to include('Woods Map refused the request')
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

    it 'exchanges ?token= once for the cookie and drops it from the URL' do
      get '/woods?token=secret-token&theme=light', env: remote
      expect(response).to redirect_to('/woods?theme=light')
      get '/woods', env: remote
      expect(response).to have_http_status(:ok)
    end

    it 'sends a wrong ?token= to the session form with the rejection' do
      get '/woods?token=nope', env: remote
      expect(response).to redirect_to('/woods/session/new')
      follow_redirect!
      expect(response.body).to include(WoodsMap::Authentication::REJECTED)
    end

    it 'exchanges the token for a signed cookie at the form and then serves pages' do
      post '/woods/session', params: { token: 'secret-token' }, env: remote
      expect(response.location).to match(%r{/woods/?\z})
      get '/woods', env: remote
      expect(response).to have_http_status(:ok)
    end

    it 'rejects a wrong token at the exchange' do
      post '/woods/session', params: { token: 'nope' }, env: remote
      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to include(WoodsMap::Authentication::REJECTED)
    end

    it 'serves the session form without the frame or any index fact' do
      get '/woods/session/new', env: remote
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('class="bar"')
      expect(response.body).not_to include('gen ')
    end

    it 'refuses a cross-origin write even with a valid token' do
      post '/woods/session', params: { token: 'secret-token' },
                             headers: { 'Origin' => 'https://evil.example', 'Authorization' => 'Bearer secret-token' },
                             env: remote
      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include('another origin')
    end
  end

  it 'lets the host authorize hook refuse before any token check' do
    WoodsMap.configuration.authorize = ->(_request) { false }
    get '/woods'
    expect(response).to have_http_status(:forbidden)
    expect(response.body).to include('config.authorize')
  end
end
