# frozen_string_literal: true

require_relative '../support/trail_index'

# The Trail's handoff summary (notes/trail.md): built in the browser from the reader's own
# notes and copied to the clipboard. The server only names what the summary links to.
RSpec.describe 'Trail handoff summary', type: :request do
  include TrailIndex

  let(:pins) { %w[job:NotifySubscribersJob mailer:MailingListMailer] }

  def page_for(params = {})
    get '/woods/trail', params: { pin: pins, token: 'never-shared' }.merge(params)
    html_response_document
  end

  def board
    page = page_for
    page.at_css('[data-controller~=pinboard]')
  end

  it 'offers a Copy handoff summary button, hidden without a script, and says it goes to the clipboard only' do
    page = page_for
    button = page.at_css('button[data-action="pinboard#copySummary"]')
    expect(button.text).to include('Copy handoff summary')
    expect(button.attributes).to have_key('data-needs-js')
    section = button.ancestors('.trail-handoff').first
    expect(section.text).to include('clipboard only', 'nothing is stored or put in a URL')
  end

  it 'has a conclusion and an open question field kept with the pin notes in this browser' do
    page = page_for
    fields = page.css('.trail-handoff textarea').to_h { |field| [field['data-pin'], field['aria-label'] || field.text] }
    expect(fields.keys).to eq(%w[conclusion question])
    expect(page.css('.trail-handoff textarea').pluck('data-pinboard-target').uniq).to eq(['note'])
  end

  it 'gives the controller the token-free board URL and the generation' do
    data = board
    expect(data['data-pinboard-url-value']).to start_with("#{request.base_url}/woods/trail?")
    expect(data['data-pinboard-url-value']).not_to include('token')
    expect(data['data-pinboard-generation-value']).to match(/\A\d+\z/)
  end

  it 'gives the controller each cited unit as an absolute focus link' do
    units = JSON.parse(board['data-pinboard-units-value'])
    expect(units.pluck('pin')).to eq(pins)
    expect(units.first).to include('label' => 'NotifySubscribersJob', 'type' => 'job',
                                   'url' => "#{request.base_url}/woods/units/job/NotifySubscribersJob")
  end

  it 'offers no handoff without a pin' do
    get '/woods/trail'
    expect(response.parsed_body.css('button[data-action="pinboard#copySummary"]')).to be_empty
  end
end
