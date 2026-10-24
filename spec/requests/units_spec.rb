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

    it 'keeps legacy source highlighted without guessing links from the private cache' do
      source = html_response_document.css('.cv .src')
      expect(source.css('a')).to be_empty
      expect(source.css('.const').map(&:text)).to include('Micropost', 'UserMailer')
    end

    it 'shows the outline rail in chain order and the status bar keys' do
      expect(response.body).to include('lifecycle, create').and include('before_save downcase_email')
      expect(response.body).to include('links: published reference spans; dashed static, dotted ambiguous')
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

  it 'offers the lifecycle as a sequence, a flowchart or lanes, falling back to the sequence' do
    { nil => %w[Sequence sequenceDiagram], 'flowchart' => ['Flowchart', 'flowchart TD'],
      'lanes' => ['Lanes', 'swimlane-beta TB'], 'c4' => %w[Sequence sequenceDiagram] }.each do |view, (title, start)|
      get '/woods/units/model/User/lifecycle', params: { event: 'update', view: view }.compact
      page = response.parsed_body
      expect(page.at_css('.dia .dh b').text).to eq(title)
      expect(page.at_css('.dia pre[data-diagram-target="source"]').text).to start_with(start)
      expect(page.at_css('[aria-label="view"] a[aria-current="true"]').text).to eq(title.downcase)
    end
  end

  it 'keeps the event across views and the view across events, and names the missing C4 view' do
    get '/woods/units/model/User/lifecycle', params: { event: 'update', view: 'lanes' }
    page = response.parsed_body
    expect(page.css('[aria-label="view"] a').pluck('href'))
      .to eq(['/woods/units/model/User/lifecycle?event=update',
              '/woods/units/model/User/lifecycle?event=update&view=flowchart',
              '/woods/units/model/User/lifecycle?event=update&view=lanes'])
    expect(page.css('[aria-label="entry"] a').first['href'])
      .to eq('/woods/units/model/User/lifecycle?event=create&view=lanes')
    expect(response.body).to include('no C4-dynamic view: it needs container attribution')
  end

  it 'draws the model\'s published state machine under its steps' do
    get '/woods/units/model/User/lifecycle'
    panel = response.parsed_body.css('.dia[data-controller="diagram"]').last
    expect(panel.at_css('.dh b').text).to eq('State')
    expect(panel.at_css('pre').text).to start_with('stateDiagram-v2').and include('s1 --> s2 : suspend [admin?]')
    expect(response.body).to include('after_transition :send_activation_email, on: :activate')
    expect(response.parsed_body.at_css('a[href="/woods/units/state_machine/User::aasm"]')).to be_present
  end

  it 'lists every transition of the machine, and leaves the section out for a model without one' do
    get '/woods/units/model/User/lifecycle'
    table = response.parsed_body.at_css('table[aria-label="Transitions of User::aasm"]')
    expect(table.css('tbody tr').map { |row| row.css('td').map(&:text) })
      .to eq([['activate', 'pending → active', '—'], ['suspend', 'active → suspended', 'admin?'],
              ['reinstate', 'suspended → active', '—']])
    get '/woods/units/model/Micropost/lifecycle'
    expect(response.body).not_to include('State machine transitions')
  end

  it 'gives each diagram panel its Mermaid text for Pele, the text kept as the fallback' do
    { 'schema' => 'erDiagram', 'lifecycle' => 'sequenceDiagram', 'graph' => 'flowchart LR' }.each do |tab, start|
      get "/woods/units/model/User/#{tab}"
      page = response.parsed_body
      panel = page.at_css('.dia[data-controller="diagram"]')
      expect(panel['data-diagram-label-value']).to match(/User|users/)
      expect(panel.at_css('pre[data-diagram-target="source"]').text).to start_with(start)
      expect(panel.at_css('[data-diagram-target="canvas"]')).to be_present
    end
  end

  it 'keeps an over-budget neighbourhood as text and names the budget' do
    stub_const('WoodsMap::Neighbourhood::NODE_BUDGET', 2)
    get '/woods/units/model/User/graph'
    page = response.parsed_body
    expect(page.at_css('.dia[data-controller="diagram"]')).to be_nil
    expect(page.at_css('.dia .refusal').text).to include('over the flowchart budget of 2')
    expect(page.at_css('.dia pre').text).to start_with('flowchart LR')
  end

  it 'keeps over-budget ER and sequence diagrams as text and names their budgets' do
    stub_const('WoodsMap::SchemaView::TABLE_BUDGET', 1)
    stub_const('WoodsMap::Lifecycle::SEQUENCE_BUDGET', 1)
    stub_const('WoodsMap::StateMachineView::STATE_BUDGET', 1)
    { 'schema' => ['over the ER budget of 1', 'erDiagram'],
      'lifecycle' => ['over the sequence budget of 1', 'sequenceDiagram'] }.each do |tab, (says, text)|
      get "/woods/units/model/User/#{tab}"
      page = response.parsed_body
      expect(page.at_css('.dia[data-controller="diagram"]')).to be_nil
      expect(page.at_css('.dia .refusal').text).to include(says)
      expect(page.at_css('.dia pre').text).to start_with(text)
    end
  end

  it 'gives a drawn panel a hidden status line for a renderer refusal' do
    get '/woods/units/model/User/schema'
    message = response.parsed_body.at_css('.dia[data-controller="diagram"] [data-diagram-target="message"]')
    expect(message['role']).to eq('status')
    expect(message).to have_attribute('hidden')
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

  it 'renders the passage of a controller action with its stages, matrix and ladder' do
    get '/woods/units/controller/UsersController/passage?action_name=edit'
    title = '<h1 class="t1">UsersController#edit<span class="sub">GET /users/:id/edit</span></h1>'
    expect(response.body).to include(title).and include('Filter matrix')
    expect(response.body).to include('href="/woods/units/controller/UsersController#L2">logged_in_user</a>')
    expect(response.body).to include('<th class="c cur" width="66">edit</th>')
    expect(response.body).to include('Callback ladder, <a href="/woods/units/model/User">User</a>')
  end

  it 'renders the passage of a mailer action from its templates' do
    get '/woods/units/mailer/UserMailer/passage'
    expect(response.body).to include('UserMailer#account_activation')
    expect(response.body).to include('user_mailer/account_activation.html.erb')
    expect(response.body).to include('not in the index')
  end

  it 'flags the seeded instance variable on the mailer passage, with the template it is read in' do
    get '/woods/units/mailer/MailingListMailer/passage?action_name=new_post'
    expect(response.body).to include('<span class="iv bad">@preferences</span>, no recorded assignment')
    template = '/woods/units/view_template/mailing_list_mailer/new_post.html.erb'
    expect(response.body).to include(%(is mentioned in <a href="#{template}">))
  end

  it 'shows the assigns a filter makes for the action, at their lines' do
    get '/woods/units/controller/UsersController/passage?action_name=edit'
    expect(response.body).to include('correct_user</a> only: edit, update, assigns <span class="iv">@user</span>')
    expect(response.body).to include('Flag coverage is incomplete')
  end

  it 'sets permitted keys against the model and leaves unmatched ones unverified, not flagged' do
    get '/woods/units/controller/UsersController/passage?action_name=create'
    expect(response.body).to include('column: <span class="iv">name</span>, <span class="iv">email</span>')
    expect(response.body).to include('unverified: <span class="iv">password</span>, ' \
                                     '<span class="iv">password_confirmation</span>')
    expect(response.body).to include('Unverified, not flagged', 'woods#797', 'woods#798')
    expect(response.body).not_to include('<span class="iv bad">password</span>')
  end

  it 'names partial locals as a limit where partials are shown' do
    get '/woods/units/controller/UsersController/passage?action_name=show'
    expect(response.body).to include('Partial locals are not checked', 'partial locals passed and read')
  end

  it 'sends a type without actions from the passage route to its Code tab' do
    get '/woods/units/model/User/passage'
    expect(response).to redirect_to('/woods/units/model/User')
  end

  it 'answers 404 with an empty state for an unknown unit' do
    get '/woods/units/model/Nope'
    expect(response).to have_http_status(:not_found)
    expect(response.body).to include('No model named Nope')
  end

  it 'carries the file tree in the sheet with the current file marked' do
    get '/woods/units/model/User'
    expect(response.body).to include('class="f" href="/woods/files/app/models/micropost.rb"')
    expect(response.body).to match(/aria-current="true"[^>]*data-tree-target="row"><span class="nm">user\.rb/)
  end
end
