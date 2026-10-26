# frozen_string_literal: true

RSpec.describe 'C4 dynamic views', type: :request do
  context 'with container attribution' do
    before { WoodsMap.configuration.index_dir = WoodsMap::LandscapeIndex.path }

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

    it 'draws no save for an action whose name implies no model event, on the page or in the .mmd' do
      get '/woods/units/controller/UsersController/passage?action_name=edit'
      document = html_response_document
      c4 = document.at_css('[data-controller~=diagram] pre').text
      expect(c4).to include('subgraph web').and not_include('save User').and not_include('INSERT')
      expect(response.body).to include('implies no model save')
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
