# frozen_string_literal: true

RSpec.describe 'What the Schema tab says the evidence means', type: :request do
  def page_text
    body = response.parsed_body
    (body.is_a?(String) ? Nokogiri::HTML(body) : body).text.squish
  end

  def association_row(name)
    body = response.parsed_body
    document = body.is_a?(String) ? Nokogiri::HTML(body) : body
    document.css('table tr').find { |row| row.text.include?(":#{name}") }&.text&.squish
  end

  it 'shows the far table foreign key behind a has_many, with no bare dash' do
    get '/woods/units/model/User/schema'
    expect(association_row('microposts')).to include('✓ FK microposts.user_id → users')
    expect(association_row('active_relationships'))
      .to include('unchecked: no foreign key to users published on relationships')
  end
end
