# frozen_string_literal: true

RSpec.describe 'Indexed navigation', type: :request do
  let(:path) { 'app/models/report query.雪.rb' }
  let(:entries) do
    [{ 'identifier' => 'Report', 'type' => 'model', 'file_path' => path },
     { 'identifier' => 'Report', 'type' => 'factory', 'file_path' => path },
     { 'identifier' => 'Report', 'type' => 'model', 'file_path' => path },
     { 'identifier' => 'Floating', 'type' => 'new_type' }]
  end
  let(:graph) do
    { 'nodes' => { 'Report' => { 'type' => 'model', 'file_path' => path },
                   'settings' => { 'type' => 'configuration', 'kind' => 'file_profile', 'file_path' => path } },
      'variants' => [{ 'identifier' => 'Report', 'type' => 'factory', 'file_path' => 'spec/report.rb',
                       'source_paths' => [path, 'spec/report.rb'] }],
      'file_map' => { path => %w[Report settings Missing Report], 'spec/report.rb' => ['Report'] } }
  end

  after { WoodsMap::FileTree.reset! }

  before do
    WoodsMap::FileTree.reset!
    allow(WoodsMap::Repository).to receive(:open).and_wrap_original do |original, &block|
      original.call do |repository|
        allow(repository).to receive_messages(units: entries, graph: graph,
                                              freshness: { 'state' => 'unknown' })
        block.call(repository)
      end
    end
  end

  it 'groups distinct typed entries, preserving fileless and unfamiliar types' do
    get '/woods/units'
    document = html_response_document
    expect(response).to have_http_status(:ok)
    expect(document.css('table a').pluck('href'))
      .to eq(%w[/woods/units/factory/Report /woods/units/model/Report /woods/units/new_type/Floating])
    expect(response.body).to include('3 units', 'id="type-new_type"', 'No indexed file')
  end

  it 'renders a deliberate empty units state' do
    entries.clear
    get '/woods/units'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('No indexed units', '0 units')
  end

  it 'renders every typed owner and explicit unresolved membership without source reconstruction' do
    get WoodsMap::Engine.routes.url_helpers.file_path(path: path, script_name: '/woods')
    document = html_response_document
    expect(response).to have_http_status(:ok)
    expect(document.css('table a').pluck('href'))
      .to contain_exactly('/woods/units/model/Report', '/woods/units/factory/Report',
                          '/woods/units/configuration/settings')
    expect(response.body).to include('file profile', 'Missing', 'Unresolved', '3 units')
    expect(response.body).not_to include('source_code', '#L')
  end

  it 'keeps a single-owner contributor page and selects the requested path' do
    get '/woods/files/spec/report.rb'
    expect(response).to have_http_status(:ok)
    expect(html_response_document.at_css('.sheet [data-sheet-target=tree]')['data-current']).to eq('spec/report.rb')
    expect(response.body).to include('href="/woods/units/factory/Report"')
    expect(response.body).to include('Indexed file, 1 unit, gen')
  end

  it 'offers a direct source action for a file with one typed owner and keeps the ownership table' do
    get '/woods/files/spec/report.rb'
    document = html_response_document
    action = document.at_css('.ident .ctl a.btn.primary')
    expect([action['href'], action.text]).to eq(['/woods/units/factory/Report', 'Open Report source'])
    expect(document.at_css('table[aria-label="Indexed file owners"]')).to be_present
  end

  it 'keeps the chooser alone for a file with several owners or unresolved membership' do
    get WoodsMap::Engine.routes.url_helpers.file_path(path: path, script_name: '/woods')
    expect(html_response_document.css('.ident .ctl a')).to be_empty
  end

  it 'lays the ownership sections out in the page body, like the units index' do
    get WoodsMap::Engine.routes.url_helpers.file_path(path: path, script_name: '/woods')
    sections = html_response_document.css('.page-main > .body > .main > section.sec').pluck('aria-labelledby')
    expect(sections).to eq(%w[file-owners file-unresolved])
  end

  it 'publishes exact typed owner keys for client filtering without file-map guesses' do
    get '/woods/tree'
    rows = html_response_document.css('.tree a[data-owner-keys]')
    row = rows.find { |element| element['data-path'] == path }
    expect(JSON.parse(row['data-owner-keys']))
      .to contain_exactly(%w[Report model], %w[Report factory], %w[settings configuration])
  end

  it 'returns a missing ownership page for an unindexed key' do
    get '/woods/files/missing.rb'
    expect(response).to have_http_status(:not_found)
    expect(response.body).to include('File is not indexed')
  end

  it 'links file search results to files and marks them as files' do
    get '/woods/search', params: { q: 'report query', in: 'path' }
    document = html_response_document
    expect(document.css('table a').pluck('href'))
      .to include(WoodsMap::Engine.routes.url_helpers.file_path(path: path, script_name: '/woods'))
    expect(document.css('table').text).to include('file')
  end

  it 'returns engine-generated file and typed unit URLs in the palette' do
    get '/woods/search/palette', params: { q: 'report' }
    files = response.parsed_body['groups'].find { |group| group['name'] == 'files' }
    expect(files['items'].first).to include('type' => 'file', 'file_path' => path)
    expect(files['items'].first['href'])
      .to eq(WoodsMap::Engine.routes.url_helpers.file_path(path: path, script_name: '/woods'))
  end

  it 'uses the units index for Units navigation and type breadcrumbs' do
    get '/woods/units/model/User'
    expect(response.body).to include('href="/woods/units"', 'href="/woods/units#type-model"')
  end

  it 'authenticates units and files before opening an index' do
    WoodsMap.configuration.authorize = ->(_) { false }
    get '/woods/units'
    expect(response).to have_http_status(:forbidden)
    get '/woods/files/spec/report.rb'
    expect(response).to have_http_status(:forbidden)
    expect(WoodsMap::Repository).not_to have_received(:open)
  end
end
