# frozen_string_literal: true

RSpec.describe 'Rate limits', type: :request do
  before do
    WoodsMap.configuration.rate_limit = 2
    WoodsMap.configuration.rate_limit_period = 60
  end

  it 'answers 429 JSON with Retry-After once the palette budget is spent' do
    2.times do
      get '/woods/search/palette', params: { q: 'User' }
      expect(response).to have_http_status(:ok)
    end
    get '/woods/search/palette', params: { q: 'User' }
    expect(response).to have_http_status(:too_many_requests)
    expect(response.headers['Retry-After'].to_i).to be_between(1, 60)
    expect(response.parsed_body).to include('error' => 'rate_limited',
                                            'message' => start_with('Too many requests: 2 per 60s'))
  end

  it 'shares the search budget between the results page and the palette' do
    get '/woods/search', params: { q: 'User' }
    get '/woods/search/palette', params: { q: 'User' }
    get '/woods/search', params: { q: 'User' }
    expect(response).to have_http_status(:too_many_requests)
    expect(response.body).to include('Woods Map is pacing requests').and include('HTTP 429')
    expect(response.body).not_to include('class="bar"')
    expect(response.body).not_to include('gen ')
  end

  it 'keeps a budget per group and leaves other pages alone' do
    3.times { get '/woods/search', params: { q: 'User' } }
    expect(response).to have_http_status(:too_many_requests)
    get '/woods/impact', params: { focus: 'User' }
    expect(response).to have_http_status(:ok)
    get '/woods/graph/neighbourhood', params: { centre: 'User', type: 'model' }
    expect(response).to have_http_status(:ok)
    3.times { get '/woods/units/model/User' }
    expect(response).to have_http_status(:ok)
  end

  it 'limits the graph JSON and the impact page' do
    3.times { get '/woods/graph/neighbourhood', params: { centre: 'User', type: 'model' } }
    expect(response).to have_http_status(:too_many_requests)
    expect(response.parsed_body['error']).to eq('rate_limited')
    3.times { get '/woods/impact', params: { focus: 'User' } }
    expect(response).to have_http_status(:too_many_requests)
    expect(response.body).to include('The impact page answered 2 requests')
  end

  it 'counts per client' do
    2.times { get '/woods/search', params: { q: 'User' } }
    WoodsMap.configuration.token = 'secret-token'
    get '/woods/search', params: { q: 'User' }, headers: { 'Authorization' => 'Bearer secret-token' },
                         env: { 'REMOTE_ADDR' => '203.0.113.9' }
    expect(response).to have_http_status(:ok)
  end

  it 'lets the host key the budget, for example by user' do
    WoodsMap.configuration.rate_limit_key = ->(request) { request.headers['X-User'] }
    2.times { get '/woods/search', params: { q: 'User' }, headers: { 'X-User' => 'ada' } }
    get '/woods/search', params: { q: 'User' }, headers: { 'X-User' => 'grace' }
    expect(response).to have_http_status(:ok)
  end

  it 'refuses before counting a client the gate refuses' do
    3.times { get '/woods/search', params: { q: 'User' }, env: { 'REMOTE_ADDR' => '203.0.113.9' } }
    expect(response).to have_http_status(:forbidden)
    expect(WoodsMap.configuration.rate_limiter.size).to eq(0)
  end

  it 'turns off with a nil budget' do
    WoodsMap.configuration.rate_limit = nil
    3.times { get '/woods/search/palette', params: { q: 'User' } }
    expect(response).to have_http_status(:ok)
  end
end
