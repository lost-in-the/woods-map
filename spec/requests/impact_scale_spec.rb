# frozen_string_literal: true

require_relative '../support/range_report_fixture'

# The impact page at scale and at its edges: a range of hundreds of changes
# renders bounded pages; a range whose endpoints are one payload says nothing
# changed; the pre-change lists put the units a change ripples through first;
# and every lens count moves with the depth.
RSpec.describe 'Impact at scale', type: :request do
  include RangeReportFixture

  def many_changes(count)
    Array.new(count) do |i|
      { 'identifier' => format('Widget%04d', i), 'type' => 'model', 'status' => 'modified', 'facets' => ['source'],
        'categories' => ['behaviour'], 'metadata_keys' => [] }
    end
  end

  def changed_rows
    response.parsed_body.css('table[aria-label="Changed units"] tbody tr[id^=changed-]')
  end

  describe 'a range with hundreds of changes' do
    before { stub_range_report(range_report_data.merge('changed' => many_changes(450))) }

    it 'renders one bounded page with links to the next, keeping the query' do
      get '/woods/impact', params: { from: 'gen:1', lens: 'changed' }
      expect(changed_rows.size).to eq(200)
      pager = response.parsed_body.at_css('#chg ~ * .pager, .pager')
      expect(pager.text).to include('1–200 of 450')
      expect(pager.at_css('a')['href']).to include('cpage=2', 'lens=changed', 'from=gen%3A1').and end_with('#chg')
    end

    it 'renders the last page short, numbered where the list left off' do
      get '/woods/impact', params: { from: 'gen:1', lens: 'changed', cpage: 3 }
      expect(changed_rows.size).to eq(50)
      expect(changed_rows.first['id']).to eq('changed-401')
    end

    it 'opens the page that holds the focused unit' do
      get '/woods/impact', params: { from: 'gen:1', lens: 'changed', focus: 'Widget0250' }
      expect(changed_rows.first['id']).to eq('changed-201')
      expect(response.parsed_body.at_css('tr[aria-current=true]')['id']).to eq('changed-251')
    end
  end

  it 'says nothing changed when both endpoints are one generation' do
    same = range_report_endpoints.transform_values { |endpoint| endpoint.merge('generation' => 1) }
    stub_range_report(range_report_data.merge('range' => same, 'changed' => [], 'affected' => []))
    get '/woods/impact', params: { from: 'gen:1', lens: 'changed' }
    expect(response.parsed_body.at_css('.empty-state').text).to include('Nothing changed: both endpoints are gen 1')
  end

  describe 'pre-change mode' do
    it 'puts the units a change ripples through above the ones nothing depends on, nearest first' do
      radius = WoodsMap::Repository.open { |repository| WoodsMap::BlastRadius.new(repository, focus: 'User', depth: 2) }
      weights = WoodsMap::Repository.open do |repository|
        radius.affected.map { |a| [a.distance, repository.graph.dig('pagerank', a.identifier).to_f] }
      end
      expect(weights).to eq(weights.sort_by { |distance, weight| [distance, -weight] })
    end
  end
end
