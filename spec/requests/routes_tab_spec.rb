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
    expect(rows).to include(%w[UsersController controller redirect_to])
  end

  it 'redirects other unit types to their Code tab' do
    get '/woods/units/model/User/routes'
    expect(response).to redirect_to('/woods/units/model/User')
  end
end
