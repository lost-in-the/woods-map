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
    expect(banner).to include('Modified since gen 1.', 'metadata keys: callbacks, loc', 'source lines did not move')
  end

  describe 'the diff gutter' do
    let(:lines) do
      { 'hunks' => [{ 'before' => [25, 1], 'after' => [25, 1] }, { 'before' => [35, 2], 'after' => [34, 0] }],
        'added_lines' => 1, 'removed_lines' => 3, 'coverage' => 'complete' }
    end

    before do
      changes = range_report_changes.map { |c| c['identifier'] == 'User' ? c.merge('source_changes' => lines) : c }
      stub_range_report(range_report_data.merge('changed' => changes))
    end

    it "marks the lines Woods' report records as changed and where lines were removed" do
      get '/woods/units/model/User', params: { since: 'gen:1' }
      expect(doc.css('.cv .row.row-chg').pluck('id')).to include('L2')
      expect(doc.at_css('#L2 .ln').text).to eq('2, changed since gen 1')
      removed = doc.at_css('.cv .row.row-rm')
      expect([removed['id'],
              removed.at_css('.ln')['title']]).to eq(['L11', '2 lines removed after this line since gen 1'])
    end

    it 'marks a note M when its own line changed and says so in the banner' do
      get '/woods/units/model/User', params: { since: 'gen:1' }
      expect(doc.at_css('#L2 .mg .M')).to be_present
      expect(doc.at_css('#L2 .mg .sr-only').text).to start_with('its line changed since gen 1')
      expect(doc.at_css('.banner.mod').text.squish).to include('Lines: 1 line added, 3 removed')
    end

    it 'marks no line when the report addresses another generation than the page' do
      data = range_report_data
      data['range']['to']['generation'] = 2
      stub_range_report(data.merge('changed' => range_report_changes.map { |c| c.merge('source_changes' => lines) }))
      get '/woods/units/model/User', params: { since: 'gen:1' }
      expect(doc.css('.cv .row.row-rm')).to be_empty
      expect(doc.at_css('.banner.mod').text.squish).to include('address gen 2, not gen 1')
    end
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

  it 'marks the files of changed units in the file tree' do
    get '/woods/units/model/User', params: { since: 'gen:1' }
    tree = doc.at_css('.sheet nav.tree')
    expect(tree.at_css('.th').text).to include('changed since gen 1')
    marked = tree.css('a.f').select { |a| a.at_css('.M') }.pluck('data-path')
    expect(marked).to include('app/models/user.rb')
    expect(tree.at_css('a.f[data-path="app/models/micropost.rb"] .M')).to be_nil
  end

  describe 'filters and columns (woods#820, woods#821)' do
    def report_with(*records)
      stub_range_report(range_report_data.merge('changed' => range_report_changes + records))
    end

    it 'marks the filter-matrix row whose declaration holds a changed line' do
      lines = { 'hunks' => [{ 'before' => [34, 1], 'after' => [34, 1] }], 'added_lines' => 1, 'removed_lines' => 1,
                'coverage' => 'complete' }
      report_with({ 'identifier' => 'UsersController', 'type' => 'controller', 'status' => 'modified',
                    'facets' => ['source'], 'metadata_keys' => [], 'source_changes' => lines })
      get '/woods/units/controller/UsersController/passage', params: { action_name: 'edit', since: 'gen:1' }
      rows = doc.css('table[aria-label="Filter matrix"] tbody tr.chg')
      expect(rows.map { |tr| tr.at_css('td a, td').text }).to all(include('correct_user'))
      expect(rows.size).to eq(1)
      expect(rows.first.at_css('.sr-only').text).to include('its declaration changed since gen 1')
    end

    def column_records
      columns = { 'added' => ['state'], 'removed' => ['legacy'], 'modified' => ['content'] }
      report_with({ 'identifier' => 'table:microposts', 'type' => 'database_table', 'status' => 'modified',
                    'facets' => ['metadata'], 'metadata_keys' => ['columns'], 'column_changes' => columns },
                  { 'identifier' => 'Micropost', 'type' => 'model', 'status' => 'modified', 'facets' => ['metadata'],
                    'metadata_keys' => ['columns'], 'column_changes' => columns.merge('added' => []) })
    end

    it 'marks moved columns on the ERD list and in its diagram' do
      column_records
      get '/woods/erd', params: { since: 'gen:1' }
      expect(doc.at_css('table[aria-label="Tables in this chunk"]').text).to include('+state ~content −legacy')
      expect(response.body).to include('content &quot;modified since gen 1&quot;')
    end

    it 'marks moved columns on the Schema tab and lists the removed ones' do
      column_records
      get '/woods/units/model/Micropost/schema', params: { since: 'gen:1' }
      rows = doc.css('table[aria-label="Columns"] tbody tr.chg')
      expect(rows.map { |tr| tr.css('td').first.text }).to eq(['M modified since gen 1:  content'])
      expect(doc.at_css('section[aria-labelledby="colsh"] .cap').text).to include('removed since gen 1: legacy')
    end
  end

  it 'says on the ERD how many tables moved' do
    get '/woods/erd', params: { since: 'gen:1' }
    expect(doc.at_css('.banner').text).to include('0 tables changed since gen 1.')
  end
end
