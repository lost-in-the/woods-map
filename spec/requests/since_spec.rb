# frozen_string_literal: true

require_relative '../support/range_report_fixture'

RSpec.describe '?since= highlighting from Woods\' range report', type: :request do
  include RangeReportFixture

  def doc
    response.parsed_body
  end

  before { stub_range_report }

  it 'says what moved on the Code tab, from Woods\' report since that generation' do
    get '/woods/units/model/User', params: { since: 'gen:1' }
    expect(WoodsMap::ImpactRange).to have_received(:new).with(anything, from: 'gen:1', to: 'now')
    banner = doc.at_css('.banner.mod').text.squish
    expect(banner).to include('Modified since gen 1.', 'metadata keys: callbacks, loc', 'woods#802')
  end

  it 'marks the notes that read a moved key and keeps since on the tabs' do
    get '/woods/units/model/User', params: { since: 'gen:1' }
    marked = doc.css('.cv .row.row-chg .mg').map { |mg| mg.at_css('b').text }
    expect(marked).not_to be_empty
    expect(marked).to all(start_with('chain '))
    expect(doc.css('.cv .row:not(.row-chg) .mg b').map(&:text)).to include(a_string_including('→ users'))
    expect(doc.css('.page-tabs a').pluck('href')).to all(include('since=gen%3A1'))
  end

  it 'tints the Graph tab with the report and says when a unit was only reached' do
    get '/woods/units/controller/UsersController/graph', params: { since: 'gen:1' }
    expect(doc.at_css('.banner.mod').text).to include('Affected since gen 1.', '1 hop from a changed unit')
    body = doc.at_css('.body[data-controller~="graph"]')
    expect(body['data-graph-emphasis-value']).to eq('range')
    expect(doc.css('form input[name=since]').pluck('value')).to eq(['gen:1'])
  end

  it 'marks changed templates on the Passage' do
    get '/woods/units/controller/UsersController/passage', params: { action_name: 'show', since: 'gen:1' }
    link = doc.at_css('a[href="/woods/units/view_template/users/show.html.erb?since=gen%3A1"]')
    expect(link).to be_present
    expect(link.parent.at_css('.M')).to be_present
  end

  it 'names an unchanged unit as unchanged and refuses a malformed selector without asking Woods' do
    get '/woods/units/model/Micropost', params: { since: 'gen:1' }
    expect(doc.at_css('.banner').text).to include('Unchanged since gen 1.')
    get '/woods/units/model/User', params: { since: 'yesterday' }
    expect(doc.at_css('.banner.mod').text).to include('No comparison since yesterday.')
    expect(WoodsMap::ImpactRange).to have_received(:new).once
  end

  it 'says on the ERD how many tables moved' do
    get '/woods/erd', params: { since: 'gen:1' }
    expect(doc.at_css('.banner').text).to include('0 tables changed since gen 1.')
  end
end
