# frozen_string_literal: true

# The Code tab's count is Woods' `metadata.loc` (lines neither blank nor a
# comment); the code view's header counts every line of the file. They differ
# (25 and 37 for the testbed's Post), so each says which it is.
RSpec.describe 'Line counts on the Code tab', type: :request do
  before { get '/woods/units/model/User' }

  let(:loc) { WoodsMap::Repository.open { |repository| repository.unit('User', type: 'model') }.dig('metadata', 'loc') }

  it 'labels the tab count as lines of code' do
    tab = html_response_document.css('.page-tabs .tab').find { |a| a.text.start_with?('Code') }
    expect(tab.at_css('.cnt').text).to eq("#{loc} loc")
  end

  it 'names both counts in the code header, the loc explained' do
    counts = html_response_document.at_css('.cvwrap .hdr .tools > span')
    expect(counts.text.squish).to match(/\A\d+ lines · #{loc} loc\z/)
    expect(counts.at_css('abbr')['title']).to include('neither blank nor a comment')
  end
end
