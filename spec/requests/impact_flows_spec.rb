# frozen_string_literal: true

require_relative '../support/range_report_fixture'

RSpec.describe 'Impact Flows and retention pins', type: :request do
  include RangeReportFixture

  def doc
    response.parsed_body
  end

  def flow_rows
    doc.css('table[aria-label="Flows"] > tbody > tr:not(.sub)').map do |tr|
      tr.css('td')[1..].map do |td|
        td.text.squish
      end
    end
  end

  def readers?
    Woods::PublishedIndex.method_defined?(:flow_entry_points)
  end

  describe 'pre-change mode' do
    it 'lists the entry points through the focus from Woods\' flow membership, steps opened' do
      skip 'this Woods has no flow readers (woods#805)' unless readers?

      get '/woods/impact', params: { focus: 'User', lens: 'flows' }
      expect(flow_rows.map(&:first)).to eq(['POST /micropostsMicropostsController#create',
                                            'GET /users/:idUsersController#show'])
      expect(doc.at_css('nav[aria-label="Impact tabs"] a[aria-current="page"]').text.squish).to eq('Flows 2')
      steps = doc.css('tr.sub.open .stpt tr').map { |tr| tr.text.squish }
      expect(steps).to include(a_string_including('MicropostsController#create'), a_string_including('Micropost.build'))
    end

    it 'marks the changed step M and links units of this generation' do
      skip 'this Woods has no flow readers (woods#805)' unless readers?

      get '/woods/impact', params: { focus: 'User', lens: 'flows' }
      user = doc.css('tr.sub .stpt a').find { |a| a.text == 'User' }
      expect([user['href'], user.parent.at_css('.chg, [title]')&.text]).to eq(['/woods/units/model/User', 'M'])
    end

    it 'says this Woods cannot read flow membership instead of showing zero' do
      allow_any_instance_of(WoodsMap::Repository).to receive(:flows_state).and_return(:unsupported) # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(WoodsMap::Repository).to receive(:flow_entry_points).and_return(nil) # rubocop:disable RSpec/AnyInstance
      get '/woods/impact', params: { focus: 'User', lens: 'flows' }
      expect(response.body).to include('This Woods cannot read flow membership', 'woods#805')
      expect(doc.at_css('nav[aria-label="Impact tabs"] a[aria-current="page"]').text.squish).to eq('Flows')
    end

    it 'says the generation publishes no flows when Woods has none to give' do
      allow_any_instance_of(WoodsMap::Repository).to receive(:flows_state).and_return(:absent) # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(WoodsMap::Repository).to receive(:flow_entry_points).and_return(nil) # rubocop:disable RSpec/AnyInstance
      get '/woods/impact', params: { focus: 'User', lens: 'flows' }
      expect(response.body).to include('No flow membership in this generation', 'precompute_flows')
    end
  end

  describe 'range mode' do
    let(:flow) do
      { 'entry_point' => 'UsersController#show', 'route' => { 'verb' => 'GET', 'path' => '/users/:id' },
        'changed_steps' => [{ 'identifier' => 'User', 'type' => 'model' }], 'generation' => 1, 'endpoint' => 'to' }
    end

    before { stub_range_report(range_report_data.merge('flows' => [flow])) }

    it 'renders the report\'s flows with the pinned generation\'s steps' do
      allow_any_instance_of(WoodsMap::Repository).to receive(:flow_document) # rubocop:disable RSpec/AnyInstance
        .and_return(JSON.parse(File.read(File.join(FIXTURE_INDEX, 'payloads/gen-1/flows/UsersController_show.json'))))
      get '/woods/impact', params: { from: 'gen:1', lens: 'flows', focus: 'User' }
      expect(flow_rows).to eq([['GET /users/:idUsersController#show', 'M User', '1 of 2', 'precomputed, gen 1']])
      expect(doc.at_css('table[aria-label="Flows"] tr[aria-current="true"]')['id']).to eq('flow-1')
    end

    it 'names the base generation\'s retention in the rail' do
      allow(WoodsMap::Retention).to receive(:read).and_return(WoodsMap::Retention.new(:available, [1]))
      get '/woods/impact', params: { from: 'gen:1' }
      expect(doc.css('.rail li').map { |li| li.text.squish }).to include('·base gen 1 pinned kept past retention')
    end
  end

  it 'lists pins on the status page, naming a pin whose payload is gone' do
    allow(WoodsMap::Retention).to receive(:read).and_return(WoodsMap::Retention.new(:available, [1, 7]))
    get '/woods/'
    expect(doc.at_css('dt:contains("pinned") + dd').text.squish)
      .to eq('gen 1, gen 7 payload missing, kept past retention until woods:unpin[N]')
  end

  it 'marks pinned generations among the range selectors' do
    allow(WoodsMap::Retention).to receive(:read).and_return(WoodsMap::Retention.new(:available, [1]))
    get '/woods/impact', params: { mode: 'range' }
    expect(doc.at_css('#range-selectors').parent.text.squish).to include('Retained: gen:1 pinned.')
  end
end
