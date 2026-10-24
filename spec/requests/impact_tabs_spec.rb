# frozen_string_literal: true

require_relative '../support/range_report_fixture'

RSpec.describe 'Impact tabs over a range report', type: :request do
  include RangeReportFixture

  def doc
    response.parsed_body
  end

  def tabs
    doc.css('nav[aria-label="Impact tabs"] a').map { |a| [a.text.squish, a['aria-current']] }
  end

  before { stub_range_report }

  it 'opens on Overview with the seven tabs and their record counts' do
    get '/woods/impact', params: { from: 'gen:1' }
    expect(tabs).to eq([['Overview', 'page'], ['Changed 2', nil], ['Risks 1', nil], ['Flows 0', nil], ['Tests 0', nil],
                        ['Graph 4', nil], ['Unknown 2', nil]])
    expect(doc.at_css('h1').text).to start_with('gen 1 → gen 1')
    summary = doc.css('table[aria-label="Report summary"] tbody tr').map do |tr|
      tr.css('td').first(3).map do |td|
        td.text.squish
      end
    end
    expect(summary).to include(['Changed units', '2', 'not recorded'], %w[Tests 0 not_computed])
    expect(response.body).not_to include('Markdown')
  end

  it 'lights and opens the focused changed unit on the Changed tab, linking current units with since' do
    get '/woods/impact', params: { from: 'gen:1', lens: 'changed', focus: 'users/show.html.erb' }
    row = doc.at_css('table[aria-label="Changed units"] tr[aria-current="true"]')
    expect([row['class'], row['id']]).to match([a_string_including('focus', 'grp'), 'changed-2'])
    expect(row.at_css('a')['href']).to eq('/woods/units/view_template/users/show.html.erb?since=gen%3A1')
  end

  it 'keeps historical identities as text with their generation' do
    get '/woods/impact', params: { from: 'gen:1', lens: 'changed' }
    expect(doc.at_css('table[aria-label="Affected units"]').text).to include('Gone', 'gen 0', 'unavailable')
    expect(doc.at_css('table[aria-label="Affected units"] a[href*="Gone"]')).to be_nil
  end

  it 'draws the Graph tab with the explorer centred on the focused change and the report emphasis' do
    get '/woods/impact', params: { from: 'gen:1', lens: 'graph', focus: 'users/show.html.erb' }
    body = doc.at_css('.body[data-controller~="graph"]')
    expect([body['data-graph-emphasis-value'], body['data-graph-url-value']])
      .to match(['range', a_string_including('centre=users%2Fshow.html.erb')])
    expect(JSON.parse(body['data-graph-blast-value']).map { |u| [u['identifier'], u['distance']] })
      .to eq([['User', 0], ['users/show.html.erb', 0], ['UsersController', 1]])
  end

  it 'keeps the range in the Graph tab filter form' do
    get '/woods/impact', params: { from: 'gen:1', lens: 'graph', focus: 'users/show.html.erb' }
    hidden = doc.css('form input[type=hidden]').to_h { |input| [input['name'], input['value']] }
    expect(hidden).to include('lens' => 'graph', 'from' => 'gen:1', 'to' => 'now', 'focus' => 'users/show.html.erb')
  end

  it 'lists risks, unknowns and coverage from the report' do
    get '/woods/impact', params: { from: 'gen:1', lens: 'risks' }
    expect(doc.at_css('table[aria-label="Risks"]').text).to include('hub', 'User', 'hubs, graph_analysis.json')
    get '/woods/impact', params: { from: 'gen:1', lens: 'unknown' }
    expect(doc.at_css('table[aria-label="Unknowns"]').text).to include('flow_index_unavailable', 'not_computed')
    expect(doc.at_css('table[aria-label="Coverage"]').text).to include('bounded', 'partial')
  end

  it 'renders a saved report by its ID with the same tabs' do
    allow(WoodsMap::ImpactRange).to receive(:saved)
      .and_return(instance_double(WoodsMap::ImpactRange, state: :available, data: range_report_data))
    get "/woods/impacts/#{'c' * 64}", params: { lens: 'changed' }
    expect(tabs.map(&:first)).to include('Changed 2', 'Graph 4')
    expect(doc.at_css('.crumbs').text).to include('report ccccccc')
    expect(doc.css('nav[aria-label="Impact tabs"] a').first['href']).to eq("/woods/impacts/#{'c' * 64}")
  end

  it 'says a saved report is missing instead of rendering an empty one' do
    allow(WoodsMap::ImpactRange).to receive(:saved)
      .and_return(instance_double(WoodsMap::ImpactRange, state: :missing,
                                                         message: 'No saved impact report has this ID in this index.'))
    get "/woods/impacts/#{'d' * 64}"
    expect(response.body).to include('Saved report unavailable', 'No saved impact report has this ID')
  end

  it 'answers 404 for a saved report ID the index does not hold' do
    allow(WoodsMap::ImpactRange).to receive(:saved)
      .and_return(instance_double(WoodsMap::ImpactRange, state: :missing, message: 'No saved impact report.'))
    get "/woods/impacts/#{'d' * 64}"
    expect(response).to have_http_status(:not_found)
  end

  it 'gives the pre-change page a Graph tab tinted by the blast radius' do
    get '/woods/impact', params: { focus: 'User', lens: 'graph' }
    body = doc.at_css('.body[data-controller~="graph"]')
    expect(body['data-graph-emphasis-value']).to be_nil
    expect(JSON.parse(body['data-graph-blast-value'])).not_to be_empty
    expect(tabs.map(&:first)).to include(a_string_starting_with('Graph'))
  end
end
