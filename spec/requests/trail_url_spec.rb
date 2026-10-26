# frozen_string_literal: true

RSpec.describe 'The reading trail URL', type: :request do
  it 'hands the trail the page path and query, without a token' do
    get '/woods/units/model/User', params: { lens: 'written', token: 'secret' }
    doc = html_response_document
    expect(doc.at_css('[data-controller~=trail]')['data-trail-url-value']).to eq('/woods/units/model/User?lens=written')
  end

  it 'has no query mark when the page has no query' do
    get '/woods/units/model/User'
    expect(html_response_document.at_css('[data-controller~=trail]')['data-trail-url-value'])
      .to eq('/woods/units/model/User')
  end
end
