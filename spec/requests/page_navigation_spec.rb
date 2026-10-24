# frozen_string_literal: true

# Page details found with the files sheet: one keys controller, one # in an
# action's trail title, rail entries that lead to their sections, the
# matrix's narrowing control, and a toggle column head that names only what
# the rows carry.
RSpec.describe 'Page navigation details', type: :request do
  it 'mounts the page keys once and names a passage action with one #' do
    get '/woods/units/controller/UsersController/passage', params: { action_name: 'show' }
    doc = html_response_document
    expect(doc.css('[data-controller~=keys]').size).to eq(1)
    expect(doc.at_css('[data-controller~=trail]')['data-trail-title-value']).to eq('UsersController#show')
    expect(doc.css('nav.rail a').pluck('href')).to include('#fm')
    toggle = doc.at_css('section[data-controller~=matrix] [data-matrix-target=toggle]')
    expect(toggle.text).to eq('only filters on show')
  end

  it 'heads the toggle column with details when the rows carry no checkbox' do
    get '/woods/impact', params: { focus: 'User', depth: 2 }
    expect(html_response_document.at_css('#aff').ancestors('section').first.at_css('th.tg').text).to eq('details')
  end
end
