# frozen_string_literal: true

RSpec.describe 'Impact test gaps', type: :request do
  let(:rows) do
    get '/woods/impact', params: { focus: 'User', lens: 'tests' }
    response.parsed_body.css('table[aria-label="Gaps"] tbody tr')
  end

  it 'links the unit a gap names to its page' do
    row = rows.find { |r| r.text.include?('User has no mapped test') }
    expect(row.at_css('a')['href']).to eq('/woods/units/model/User')
    expect(row.at_css('a').text).to eq('User')
    expect(row.text.squish).to include('User has no mapped test')
  end

  it 'links a direct dependent as well' do
    row = rows.find { |r| r.text.include?('UsersController has no mapped test') }
    expect(row.at_css('a')['href']).to eq('/woods/units/controller/UsersController')
  end
end
