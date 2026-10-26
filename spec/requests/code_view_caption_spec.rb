# frozen_string_literal: true

# The as-written source is what extraction read from the working tree, which
# is not necessarily a commit.
RSpec.describe 'Code view caption', type: :request do
  it 'describes the as-written lens as extracted source, not a commit' do
    get '/woods/units/model/User', params: { lens: 'written' }
    caption = html_response_document.at_css('.cv .hdr > span').text
    expect(caption).to eq('source as extraction read it from the working tree, not necessarily a commit')
  end

  it 'keeps the effective lens caption' do
    get '/woods/units/model/User', params: { lens: 'effective' }
    expect(html_response_document.at_css('.cv .hdr > span').text).to start_with('schema header and concern bodies')
  end
end
