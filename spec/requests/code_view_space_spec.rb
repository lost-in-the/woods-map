# frozen_string_literal: true

require_relative '../support/hover_card_index'

# The code view keeps the notes lane only for a unit that has notes.
RSpec.describe 'Code view space', type: :request do
  let(:grid) { html_response_document.at_css('.cvwrap .cv') }

  context 'with a unit that has notes' do
    before { get '/woods/units/model/User' }

    it 'keeps the notes lane' do
      expect(html_response_document.css('.cv .mg b')).not_to be_empty
      expect(grid['class'].split).not_to include('nomargin')
    end
  end

  context 'with a unit that has no notes' do
    include HoverCardIndex

    before { get '/woods/units/model/Caller' }

    it 'drops the empty notes lane' do
      expect(html_response_document.css('.cv .mg b')).to be_empty
      expect(grid['class'].split).to include('nomargin')
    end
  end
end
