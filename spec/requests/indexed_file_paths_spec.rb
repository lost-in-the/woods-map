# frozen_string_literal: true

RSpec.describe 'Indexed file paths', type: :request do
  let(:file_map) { { 'app/models/user.rb' => [] } }
  let(:repositories) { [] }
  let(:graph) { { 'nodes' => {}, 'file_map' => file_map } }

  after { WoodsMap::FileTree.reset! }

  before do
    WoodsMap::FileTree.reset!
    allow(WoodsMap::Repository).to receive(:open).and_wrap_original do |original, &block|
      original.call do |repository|
        allow(repository).to receive_messages(graph: graph, freshness: { 'state' => 'unknown' })
        allow(repository).to receive(:unit).and_call_original
        repositories << repository
        block.call(repository)
      end
    end
  end

  paths = { '/woods/files/' => '', '/woods/files//outside.rb' => '/outside.rb',
            '/woods/files/C%3A/outside.rb' => 'C:/outside.rb', '/woods/files/C%3Aoutside.rb' => 'C:outside.rb',
            '/woods/files/app%5Coutside.rb' => 'app\\outside.rb',
            '/woods/files/app/%2e/outside.rb' => 'app/./outside.rb',
            '/woods/files/app/%2e%2e/outside.rb' => 'app/../outside.rb',
            '/woods/files/app/%2Foutside.rb' => 'app//outside.rb',
            '/woods/files/app/%00outside.rb' => "app/\x00outside.rb",
            '/woods/files/app/%0Aoutside.rb' => "app/\noutside.rb",
            '/woods/files/app/%7Foutside.rb' => "app/\x7foutside.rb",
            '/woods/files/app//models/user.rb' => 'app//models/user.rb',
            '/woods/files//app/models/user.rb' => '/app/models/user.rb',
            '/woods/files/app/models/user.rb/' => 'app/models/user.rb/' }
  paths.each do |url, decoded|
    it "rejects the routed key #{url} even if the payload lists it" do
      file_map[decoded] = []
      get url
      expect(response).to have_http_status(:not_found)
    end
  end

  it 'never loads stored unit source to reconstruct file contents' do
    get '/woods/files/app/models/user.rb'
    expect(response).to have_http_status(:ok)
    expect(repositories.first).not_to have_received(:unit)
  end

  it 'does not decode literal percent segments twice' do
    file_map['app/%2e%2e/outside.rb'] = []
    get '/woods/files/app/%252e%252e/outside.rb'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('app/%2e%2e/outside.rb', 'No resolved typed owners')
  end

  it 'uses helpers for spaces, Unicode, extensions and reserved characters' do
    key = 'app/report #1?雪.html.erb'
    file_map[key] = []
    url = WoodsMap::Engine.routes.url_helpers.file_path(path: key, script_name: '/woods')
    get url
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(ERB::Util.html_escape(key))
  end

  it 'escapes indexed path text in search output' do
    file_map['app/<img src=x onerror=alert(1)>.rb'] = []
    get '/woods/search', params: { q: 'img', in: 'path' }
    expect(response.body).to include('&lt;<mark>img</mark>')
    expect(response.body).not_to include('<img src=x')
  end

  it 'keeps route-generated file URLs within an alternate engine mount' do
    file_map['app/雪 report.html.erb'] = []
    get '/catalog/map/search/palette', params: { q: 'report' }
    file = response.parsed_body['groups'].find { |group| group['name'] == 'files' }['items'].first
    expect(file['href']).to start_with('/catalog/map/files/')
    get file['href']
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('href="/catalog/map/units"')
  end
end
