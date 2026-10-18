# frozen_string_literal: true

RSpec.describe 'Impact', type: :request do
  it 'renders the blast radius of a focus with its tabs and the affected units' do
    get '/woods/impact', params: { focus: 'User', depth: 2 }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('<h1 class="t1">Blast radius<span class="sub">User, depth 2, gen 1</span></h1>')
    expect(response.body).to include('Risks <span class="cnt">2</span>').and include('Tests <span class="cnt">0</span>')
    expect(response.body).to include('href="/woods/units/controller/MicropostsController"').and include('2 hops')
  end

  it 'answers every lens' do
    %w[risks flows tests unknown].each do |lens|
      get '/woods/impact', params: { focus: 'User', lens: lens }
      expect(response).to have_http_status(:ok)
    end
    get '/woods/impact', params: { focus: 'User', lens: 'risks' }
    expect(response.body).to include('A hub is in the focus').and include('needs a range')
  end

  it 'names a range it cannot report and a focus it cannot find' do
    get '/woods/impact', params: { from: 'gen:1', to: 'gen:2' }
    expect(response.body).to include('No impact report for gen:1 → gen:2')
    get '/woods/impact', params: { focus: 'Nope' }
    expect(response.body).to include('No unit named Nope in gen 1')
    get '/woods/impact'
    expect(response.body).to include('Pick a focus')
  end

  it 'links the blast radius from the Graph tab' do
    get '/woods/units/model/User/graph'
    expect(response.body).to include('href="/woods/impact?depth=2&amp;focus=User"')
  end
end
