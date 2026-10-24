# frozen_string_literal: true

# The impact page's focus row counts typed dependents from the generation's
# graph; a hub note counts graph_analysis dependents per identifier. The two
# differ, so each says which it is.
RSpec.describe 'Impact dependents', type: :request do
  it 'labels the typed count and the identifier-level hub count apart' do
    get '/woods/impact', params: { focus: 'User', depth: 2 }
    section = html_response_document.at_css('#chg').ancestors('section').first
    cells = section.css('tbody tr').first.css('td').map { |td| td.text.strip }
    expect(cells).to include('6 typed units', 'hub, 19 dependents by identifier, in a cycle')
    expect(section.at_css('thead abbr[title*="typed units"]').text).to eq('dependents')
  end
end
