# frozen_string_literal: true

RSpec.describe 'C4 dynamic views', type: :request do
  context 'with container attribution' do
    let(:index) { Woods::PublishedIndex.new(Pathname.new(WoodsMap::LandscapeIndex.path)) }

    before do
      WoodsMap.configuration.index_dir = WoodsMap::LandscapeIndex.path
      allow(Woods::PublishedIndex).to receive(:open).and_yield(index)
      allow(index).to receive(:flow_document).and_return(nil)
      allow(index).to receive(:flow_document).with('UsersController#create').and_return(
        'steps' => [{ 'unit' => 'UsersController#create', 'type' => 'controller',
                      'operations' => [{ 'type' => 'call', 'target' => 'User', 'method' => 'create' }] }]
      )
    end

    it 'offers the C4 dynamic view on Lifecycle, drawn from the containers, with its .mmd text' do
      get '/woods/units/model/User/lifecycle?event=create&view=dynamic'
      document = html_response_document
      expect(document.css('[aria-label=view] a').map(&:text)).to eq(['sequence', 'flowchart', 'lanes', 'C4 dynamic'])
      expect(document.at_css('[aria-label=view] a[aria-current=true]').text).to eq('C4 dynamic')
      expect(document.at_css('[data-controller~=diagram] pre').text).to include('subgraph db_primary')
      get '/woods/units/model/User/lifecycle.mmd?event=create&view=dynamic'
      expect(response.body).to start_with('flowchart LR').and include('w[("users · INSERT")]')
    end

    it 'draws a controller passage across containers, with its .mmd text' do
      get '/woods/units/controller/UsersController/passage?action_name=create'
      expect(response.body).to include('Across containers', 'subgraph web [&quot;Web process')
      get '/woods/units/controller/UsersController/passage.mmd?action_name=create&view=dynamic&event=create'
      expect(response.body).to start_with('flowchart LR').and include('action -->|"save User"|')
    end

    it 'keeps a different selected event separate from the action on the page and export' do
      get '/woods/units/controller/UsersController/passage?action_name=create&event=destroy'
      expect(response.body).to include('Related lifecycle,', 'not a step of create')
      text = html_response_document.at_css('[data-controller~=diagram] pre').text
      expect(text).not_to include('save User', 'DELETE', 'INSERT')
      href = html_response_document.at_css('a[href*="view=dynamic"]')['href']
      get href
      expect(response.body.strip).to eq(text.strip)
    end

    it 'returns event navigation to the lifecycle without changing the action or event query' do
      get '/woods/units/controller/UsersController/passage?action_name=edit&event=create'
      document = html_response_document
      links = document.css('.event-pick a')
      expect(links.pluck('href')).to eq(
        WoodsMap::Lifecycle::EVENTS.map do |event|
          "/woods/units/controller/UsersController/passage?action_name=edit&event=#{event}#cl"
        end
      )
      expect(document.at_css('#cl').text).to include('Related lifecycle, User')
    end

    it 'keeps the chosen event separate from the selected action after event navigation' do
      get '/woods/units/controller/UsersController/passage?action_name=edit&event=create'
      href = html_response_document.at_css('.event-pick a:last-child')['href']
      get href.split('#').first
      document = html_response_document
      expect(document.at_css('.event-pick [aria-current=true]').text).to eq('destroy')
      expect(document.at_css('#cl').text).to include('destroy')
      expect(response.body).to include('not a step of edit')
    end

    it 'does not attach a write based only on a CRUD action name' do
      allow(index).to receive(:flow_document).with('UsersController#create').and_return(nil)
      get '/woods/units/controller/UsersController/passage?action_name=create'
      expect(response.body).to include('Related lifecycle,', 'not a step of create')
      get '/woods/units/controller/UsersController/passage.mmd?action_name=create&view=dynamic'
      expect(response.body).not_to include('save User', 'INSERT')
    end

    {
      'an ambiguous target' => { 'type' => 'call', 'target' => 'User', 'method' => 'create',
                                 'ambiguous_candidates' => %w[A::User B::User] },
      'another model' => { 'type' => 'call', 'target' => 'Post', 'method' => 'create' },
      'an unqualified save' => { 'type' => 'call', 'target' => 'User', 'method' => 'save' }
    }.each do |description, operation|
      it "does not infer a create write from #{description}" do
        allow(index).to receive(:flow_document).with('UsersController#create').and_return(
          'steps' => [{ 'unit' => 'UsersController#create', 'type' => 'controller', 'operations' => [operation] }]
        )
        get '/woods/units/controller/UsersController/passage.mmd?action_name=create&view=dynamic'
        expect(response.body).not_to include('save User', 'INSERT')
      end
    end

    it 'draws no save for an action whose name implies no model event, on the page or in the .mmd' do
      get '/woods/units/controller/UsersController/passage?action_name=edit'
      document = html_response_document
      c4 = document.at_css('[data-controller~=diagram] pre').text
      expect(c4).to include('subgraph web').and not_include('save User').and not_include('INSERT')
      expect(response.body).to include('published action flow')
      get '/woods/units/controller/UsersController/passage.mmd?action_name=edit&view=dynamic'
      expect(response.body).to start_with('flowchart LR').and not_include('save User').and not_include('INSERT')
      get '/woods/units/controller/UsersController/passage.mmd?action_name=edit&view=dynamic&event=create'
      expect(response.body).not_to include('save User')
    end

    it 'labels the ladder of an action with no implied event as a related lifecycle, not a step of the action' do
      get '/woods/units/controller/UsersController/passage?action_name=edit'
      expect(response.body).to include('Related lifecycle, <a href="/woods/units/model/User">User</a>')
      expect(response.body).to include('not a step of edit')
      get '/woods/units/controller/UsersController/passage?action_name=create'
      expect(response.body).not_to include('Related lifecycle')
    end
  end

  it 'keeps the dynamic view out of an index without containers, naming W-9 as the limit' do
    get '/woods/units/model/User/lifecycle?view=dynamic'
    document = html_response_document
    expect(document.css('[aria-label=view] a').map(&:text)).to eq(%w[sequence flowchart lanes])
    expect(response.body).to include('no C4-dynamic view: it needs container attribution')
    get '/woods/units/controller/UsersController/passage?action_name=create'
    expect(response.body).not_to include('Across containers')
    get '/woods/units/controller/UsersController/passage.mmd?action_name=create&view=dynamic'
    expect(response).to have_http_status(:not_found)
  end
end
