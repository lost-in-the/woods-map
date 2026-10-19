# frozen_string_literal: true

RSpec.describe 'Search', type: :request do
  it 'finds units by name with a type filter in the rail' do
    get '/woods/search', params: { q: 'user', in: 'name' }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('href="/woods/units/model/User"')
    expect(response.body).to include('href="/woods/units/controller/UsersController"')
    expect(response.body).to include('name="types[]" value="model"')
  end

  it 'searches code and shows the matching lines as snippets with line links' do
    get '/woods/search', params: { q: 'remember_token', in: 'code' }
    expect(response.body).to include('<mark>remember_token</mark>').and include('href="/woods/units/model/User#L36"')
    expect(response.body).to include('class="snip codeview"')
  end

  it 'searches paths' do
    get '/woods/search', params: { q: 'microposts/', in: 'path' }
    expect(response.body).to include('app/views/microposts/_micropost.html.erb')
  end

  it 'keeps the frame on an empty result and names the nearest names' do
    get '/woods/search', params: { q: 'Userz', in: 'name' }
    expect(response.body).to include('Nothing matches &quot;Userz&quot;')
    expect(response.body).to include('Nearest names: <a href="/woods/units/model/User">User</a>')
  end

  it 'answers the palette with grouped hits and completeness' do
    get '/woods/search/palette', params: { q: 'user' }
    json = response.parsed_body
    expect(json['groups'].pluck('name')).to include('units', 'routes', 'tables', 'files')
    tables = json['groups'].find { |g| g['name'] == 'tables' }
    expect(tables['items'].first).to include('identifier' => 'table:users', 'type' => 'database_table')
    expect(json['complete']).to be(true)
  end
end
