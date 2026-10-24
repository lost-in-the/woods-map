# frozen_string_literal: true

RSpec.describe 'The controller Routes tab', type: :request do
  before { get '/woods/units/controller/UsersController/routes' }

  let(:doc) { html_response_document }

  it 'sits between Code and Passage with the route count' do
    expect(response).to have_http_status(:ok)
    tabs = doc.css('.page-tabs a').map { |a| a.text.squish }
    expect(tabs.first(3)).to eq(['Code', 'Routes 11', 'Passage 9'])
    expect(doc.at_css('.page-tabs a[aria-current="page"]').text).to start_with('Routes')
  end

  it 'lists every declared route with its action, helpers and route unit' do
    rows = doc.css('table[aria-label="Routes"] tbody tr').map { |tr| tr.css('td').map { |td| td.text.squish } }
    expect(rows.size).to eq(11)
    expect(rows).to include(['GET /users/:id/edit', 'edit', 'edit_user_path, edit_user_url', 'no route unit', '—'])
    show = doc.at_css('table[aria-label="Routes"] a[href="/woods/units/route/GET%20/users/:id"]')
    expect(show&.text).to eq('GET /users/:id')
    expect(rows.find { |row| row.first == 'GET /users' }[3]).to eq('L14')
  end

  it 'lists action sources with their lines and passage links' do
    rows = doc.css('table[aria-label="Action sources"] tbody tr').map { |tr| tr.css('td').map { |td| td.text.squish } }
    expect(rows.map(&:first)).to eq(%w[create destroy edit followers following index new show update])
    expect(rows.find do |row|
      row.first == 'new'
    end).to eq(['new', 'UsersController', 'app/controllers/users_controller.rb:16', '2'])
    expect(doc.at_css('a[href="/woods/units/controller/UsersController/passage?action_name=edit"]')).to be_present
  end

  it 'lists units reaching the controller by a route helper, by mechanism' do
    rows = doc.css('table[aria-label="Reached by a route helper"] tbody tr').map do |tr|
      tr.css('td').map do |td|
        td.text.squish
      end
    end
    expect(rows).to include(['UsersController', 'controller', 'redirect_to', 'not in this generation'])
    expect(response.body).to include('helper references name the controller, not the helper or action (woods#795)')
  end

  context 'when the generation publishes route_helper_references (woods#795)' do
    before do
      published = [{ 'helper' => 'users_url', 'route_name' => 'users', 'controller' => 'UsersController',
                     'action' => 'index', 'verb' => 'GET', 'path' => '/users', 'via' => 'redirect_to' },
                   { 'helper' => 'user_path', 'route_name' => 'user', 'controller' => 'UsersController',
                     'action' => 'show', 'verb' => 'GET', 'path' => '/users/:id', 'via' => 'redirect_to' }]
      allow(WoodsMap::Repository).to receive(:open).and_wrap_original do |open, *args, &block|
        open.call(*args) do |repository|
          allow(repository).to receive(:unit).and_wrap_original do |unit, identifier, **options|
            found = unit.call(identifier, **options)
            next found unless found && identifier == 'UsersController'

            found.deep_dup.tap { |copy| copy['metadata']['route_helper_references'] = published }
          end
          block.call(repository)
        end
      end
      get '/woods/units/controller/UsersController/routes'
    end

    it 'shows each helper a referencing unit calls and the action it reaches' do
      row = doc.css('table[aria-label="Reached by a route helper"] tbody tr').map do |tr|
        tr.css('td').map do |td|
          td.text.squish
        end
      end
      expect(row).to include(['UsersController', 'controller', 'redirect_to', 'user_path → showusers_url → index'])
      expect(doc.at_css('td a[href="/woods/units/controller/UsersController/passage?action_name=show"]')).to be_present
      expect(response.body).not_to include('(woods#795)</span>')
    end
  end

  it 'redirects other unit types to their Code tab' do
    get '/woods/units/model/User/routes'
    expect(response).to redirect_to('/woods/units/model/User')
  end
end
