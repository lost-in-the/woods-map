# frozen_string_literal: true

RSpec.describe 'Impact action on a unit page', type: :request do
  it 'offers a named action that opens Impact focused on the unit without retyping' do
    get '/woods/units/model/User/graph'
    action = response.parsed_body.css('.ident .ctl a').find { |a| a.text == 'Impact' }
    expect(action['href']).to eq('/woods/impact?focus=User')

    get action['href']
    expect(response.body).to include('<h1 class="t1">Blast radius<span class="sub">User, depth 2, gen 1</span></h1>')
  end

  it 'is on every tab of the unit' do
    %w[/woods/units/model/User /woods/units/model/User/schema /woods/units/model/User/history].each do |path|
      get path
      follow_redirect! if response.redirect?
      expect(response.parsed_body.css('.ident .ctl a').map(&:text)).to include('Impact')
    end
  end
end
