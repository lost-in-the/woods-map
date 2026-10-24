# frozen_string_literal: true

require_relative '../support/large_schema_index'

RSpec.describe 'The ERD page', type: :request do
  before { WoodsMap::Erd.reset! }

  it 'draws the first chunk with its tables, findings and the facts tiles' do
    get '/woods/erd'
    page = response.parsed_body
    expect(page.at_css('h1').text).to eq('Schema3 tables, 1 database, 1 chunk, 1 foreign key')
    source = page.at_css('.dia[data-controller="diagram"] pre[data-diagram-target="source"]')
    expect(source.text).to start_with('erDiagram')
    expect(page.at_css('table[aria-label="Tables in this chunk"]').css('tbody tr').size).to eq(3)
    expect(page.at_css('table[aria-label="Schema findings"]').text).to include('relationships.follower_id')
  end

  it 'lists ERD in the global bar, current on this page only' do
    get '/woods/erd'
    expect(response.parsed_body.css('nav[aria-label="Primary"] a').map { |a| [a.text, a['aria-current']] })
      .to eq([['Units', nil], ['Graph', nil], %w[ERD page], ['Impact', nil]])
    get '/woods/units/model/User'
    expect(response.parsed_body.at_css('nav[aria-label="Primary"] a[href="/woods/erd"]')['aria-current']).to be_nil
  end

  it 'keeps the closed choices in the links, an unknown value being the default' do
    get '/woods/erd', params: { by: 'database', columns: 'all' }
    page = response.parsed_body
    expect(page.css('[aria-label="columns"] a').pluck('href')).to eq(['/woods/erd/1?by=database',
                                                                      '/woods/erd/1?by=database&columns=all'])
    expect(page.at_css('.dia pre').text).to include('datetime created_at')
    get '/woods/erd', params: { by: 'nope', columns: 'nope' }
    expect(response.parsed_body.at_css('[aria-label="chunk by"] a[aria-current="true"]').text).to eq('namespace')
  end

  it 'answers 404 for a chunk that does not exist' do
    get '/woods/erd/2'
    expect(response).to have_http_status(:not_found)
    expect(response.body).to include('No chunk 2 by namespace')
  end

  it 'refuses anything but a chunk number in the route' do
    expect { get '/woods/erd/users' }.to raise_error(ActionController::RoutingError)
  end

  describe 'on a 300-model index' do
    before { WoodsMap.configuration.index_dir = WoodsMap::LargeSchemaIndex.path }

    it 'pages through chunks, each drawn within the budget, with the relations to other chunks listed' do
      get '/woods/erd/1'
      page = response.parsed_body
      expect(page.css('.rail li').size).to eq(13 + 2)
      expect([page.at_css('[data-key="prev-chunk"]'), page.at_css('[data-key="next-chunk"]')['href']])
        .to eq([nil, '/woods/erd/2'])
      expect(page.at_css('.dia[data-controller="diagram"] .dh b').text).to eq('Accounts 1 of 2')
      expect(page.at_css('table[aria-label="Relations to other chunks"]').text).to include('2 · Accounts 2 of 2')
    end
  end
end
