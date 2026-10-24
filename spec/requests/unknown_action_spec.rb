# frozen_string_literal: true

RSpec.describe 'An action the unit does not have', type: :request do
  it 'answers the Passage with 404 and the actions the controller has, never another action' do
    get '/woods/units/controller/UsersController/passage', params: { action_name: 'bogus' }
    expect(response).to have_http_status(:not_found)
    page = response.parsed_body
    expect(page.at_css('.empty-state h2').text).to eq('No action bogus on UsersController')
    expect(page.css('.empty-state a').pluck('href'))
      .to include('/woods/units/controller/UsersController/passage?action_name=create')
    expect(page.css('[role=tab][aria-selected=true], .tabs [aria-current]').map(&:text).join).to include('Passage')
  end

  it 'says so as text on the .mmd route' do
    get '/woods/units/controller/UsersController/passage.mmd', params: { action_name: 'bogus' }
    expect(response).to have_http_status(:not_found)
    expect(response.body).to start_with('UsersController has no action bogus; its actions: ')
  end

  it 'still shows the first action when none is named' do
    get '/woods/units/controller/UsersController/passage'
    expect(response).to have_http_status(:ok)
  end
end
