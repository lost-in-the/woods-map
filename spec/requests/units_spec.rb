# frozen_string_literal: true

RSpec.describe 'Unit pages', type: :request do
  describe 'the Code tab' do
    before { get '/woods/units/model/User' }

    it 'renders the frame: crumbs, title, tabs with counts, facts tiles' do
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<h1 class="t1">User<span class="sub">model, table users</span></h1>')
      expect(response.body).to include('Schema <span class="cnt">13</span>').and include('class="facts"')
      expect(response.body).to include('Code at L1')
    end

    it 'renders the file as written with marginalia from the index' do
      expect(response.body).to include('<div class="ln">1</div>')
      expect(response.body).to include('<span class="k">class</span> <span class="const">User</span>')
      expect(response.body).to include('chain 1 of 2 on create, writes email')
    end

    it 'links constant references to their units with their confidence' do
      verified = '<a href="/woods/units/model/Micropost" class="const" title="runtime-verified">Micropost</a>'
      static = '<a href="/woods/units/mailer/UserMailer" class="const s" title="static reference">UserMailer</a>'
      expect(response.body).to include(verified).and include(static)
    end

    it 'shows the outline rail in chain order and the status bar keys' do
      expect(response.body).to include('lifecycle, create').and include('before_save downcase_email')
      expect(response.body).to include('unmarked: runtime-verified')
    end
  end

  it 'remembers the lens per browser and shows the effective class' do
    get '/woods/units/model/User?lens=effective'
    expect(response).to redirect_to('/woods/units/model/User')
    follow_redirect!
    expect(response.body).to include('<b>Effective class</b>').and include('# schema: users')
  end

  it 'serves the schema, lifecycle and graph tabs' do
    get '/woods/units/model/User/schema'
    expect(response.body).to include('Associations <span class="n">5</span>')
    expect(response.body).to include('index_users_on_email, unique')
    get '/woods/units/model/User/lifecycle'
    expect(response.body).to include('Steps for create').and include('create_activation_digest')
    get '/woods/units/model/User/graph'
    expect(response.body).to include('List equivalent').and include('has_many')
  end

  it 'serves the history tab and the peek fragment' do
    get '/woods/units/model/User/history'
    expect(response.body).to include('Commits').and include('Leah Armstrong')
    get '/woods/units/model/User/peek'
    expect(response.body).to start_with('<div class="peek">').and include('app/models/user.rb:1')
  end

  it 'renders a controller, a table, a template and a route with their own tabs' do
    get '/woods/units/controller/UsersController'
    expect(response.body).to include('controller, 9 actions').and include('actions <span class="cnt">9</span>')
    get '/woods/units/database_table/table:users/schema'
    expect(response.body).to include('Columns <span class="n">13</span>')
    get '/woods/units/view_template/users/show.html.erb'
    expect(response.body).to include('view template, erb').and include('<span class="cm">')
    get '/woods/units/route/GET%20/users/:id'
    expect(response).to have_http_status(:ok)
  end

  it 'answers 404 with an empty state for an unknown unit' do
    get '/woods/units/model/Nope'
    expect(response).to have_http_status(:not_found)
    expect(response.body).to include('No model named Nope')
  end

  it 'carries the file tree in the sheet with the current file marked' do
    get '/woods/units/model/User'
    expect(response.body).to include('class="f" href="/woods/units/model/Micropost"')
    expect(response.body).to match(/aria-current="true"[^>]*data-tree-target="row"><span class="nm">user\.rb/)
  end
end
