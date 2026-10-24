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

    it 'says the mount is not on loopback only to a remote client' do
      get '/woods/session/new', env: remote
      expect(response.body).to include('This mount is not on loopback.')
      get '/woods/session/new'
      expect(response.body).not_to include('not on loopback')
      expect(response.body).to include('configured with a token')
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

  describe 'the token-less loopback mode and DNS rebinding' do
    it 'refuses a loopback request that names a host other than loopback' do
      host! 'rebound.example'
      get '/woods'
      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include('DNS-rebinding').and include('config.allowed_origins')
      expect(response.body).not_to include('rebound.example')
      expect(response.body).not_to include('Post')
    end

    it 'judges the raw Host header, not X-Forwarded-Host' do
      host! 'rebound.example'
      get '/woods', headers: { 'X-Forwarded-Host' => 'localhost' }
      expect(response).to have_http_status(:forbidden)
    end

    it 'serves loopback names with a port' do
      %w[localhost:3000 127.0.0.1:3106].each do |name|
        host! name
        get '/woods'
        expect(response).to have_http_status(:ok), name
      end
    end

    it 'accepts a host named in config.allowed_origins' do
      WoodsMap.configuration.allowed_origins = ['http://map.test']
      host! 'map.test'
      get '/woods'
      expect(response).to have_http_status(:ok)
    end

    it 'leaves token holders alone: a rebound page has neither the token nor the cookie' do
      WoodsMap.configuration.token = 'secret-token'
      host! 'map.example.com'
      get '/woods', headers: { 'Authorization' => 'Bearer secret-token' }
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'the origin guard on state-changing routes' do
    before { WoodsMap.configuration.token = 'secret-token' }

    let(:remote) { { 'REMOTE_ADDR' => '203.0.113.9' } }

    def post_session(headers)
      post '/woods/session', params: { token: 'secret-token' }, headers: headers, env: remote
    end

    it 'accepts the map’s own origin, by Origin or by Referer' do
      post_session('Origin' => 'http://localhost')
      expect(response).to have_http_status(:found)
      post_session('Referer' => 'http://localhost/woods/session/new')
      expect(response).to have_http_status(:found)
    end

    {
      'a foreign Origin' => { 'Origin' => 'https://evil.example' },
      'an opaque Origin' => { 'Origin' => 'null' },
      'a foreign Referer without Origin' => { 'Referer' => 'https://evil.example/form' },
      'the same host on another port' => { 'Origin' => 'http://localhost:8080' },
      'another scheme' => { 'Origin' => 'https://localhost' },
      'a cross-site fetch with no Origin or Referer' => { 'Sec-Fetch-Site' => 'cross-site' },
      'a same-site fetch with no Origin or Referer' => { 'Sec-Fetch-Site' => 'same-site' }
    }.each do |name, headers|
      it "refuses #{name}" do
        post_session(headers)
        expect(response).to have_http_status(:forbidden)
        expect(response.body).to include('another origin')
        expect(response.cookies[WoodsMap.configuration.cookie_name]).to be_nil
      end
    end

    it 'lets the Origin decide over a same-origin Referer' do
      post_session('Origin' => 'https://evil.example', 'Referer' => 'http://localhost/woods/session/new')
      expect(response).to have_http_status(:forbidden)
    end

    it 'guards sign-out too' do
      headers = { 'Origin' => 'https://evil.example', 'Authorization' => 'Bearer secret-token' }
      delete '/woods/session', headers: headers, env: remote
      expect(response).to have_http_status(:forbidden)
    end

    it 'accepts an origin named in config.allowed_origins' do
      WoodsMap.configuration.allowed_origins = ['https://map.example.com']
      post_session('Origin' => 'https://map.example.com')
      expect(response).to have_http_status(:found)
    end

    it 'lets a non-browser client through to the token check' do
      post_session({})
      expect(response).to have_http_status(:found)
    end
  end
end
