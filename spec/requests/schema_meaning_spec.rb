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

  describe 'the entity relationship diagram scope' do
    def er_section
      body = response.parsed_body
      (body.is_a?(String) ? Nokogiri::HTML(body) : body).at_css('section[aria-label="Entity relationship"]')
    end

    it 'names its scope as model associations only and counts the tables actually drawn' do
      get '/woods/units/model/User/schema'
      header = er_section.at_css('.dh').text
      expect(header).to include('model associations only')
      expect(header).to include('3 tables')
      expect(header).not_to include('1 hop')
    end

    it 'links to the whole-database ERD for the table foreign keys' do
      get '/woods/units/model/User/schema'
      link = er_section.css('a').find { |a| a['href'].to_s.end_with?('/woods/erd') }
      expect(link&.text).to include('ERD')
    end

    it 'counts a table once however many associations reach it' do
      get '/woods/units/database_table/table:users/schema'
      expect(er_section.at_css('.dh').text).to include('1 table')
      expect(er_section.at_css('.dh').text).not_to include('1 tables')
    end
  end
end
