# frozen_string_literal: true

# The bar's freshness comes from Woods' quick source check, which reads
# source files. It runs once per index generation for a short while, not on
# every request, and its reasons are on the status page in plain words, not
# only in a tooltip.
RSpec.describe 'Freshness', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:report) do
    { 'state' => 'unknown', 'generation' => 1, 'checked_at' => '2026-10-24T12:00:00Z',
      'counts' => { 'added' => 0, 'changed' => 0, 'removed' => 0 },
      'coverage' => { 'recorded_files' => 177, 'verified_files' => 120 },
      'reasons' => %w[scan_time_budget unverified_boot_boundary], 'recommendations' => %w[deep_check fresh_capture] }
  end

  before { WoodsMap::FreshnessCache.reset! }
  after { WoodsMap::FreshnessCache.reset! }

  def stub_status
    status = instance_double(Woods::SourceInputs::Status, call: report)
    allow(Woods::SourceInputs::Status).to receive(:new).and_return(status)
    status
  end

  it 'runs the quick check once for the pinned generation across requests' do
    status = stub_status
    2.times { get '/woods' }
    get '/woods/units'

    expect(status).to have_received(:call).once
  end

  it 'checks again once the cached answer is older than its time to live' do
    status = stub_status
    get '/woods'
    travel_to(Time.current + WoodsMap::FreshnessCache::TTL + 1) { get '/woods' }

    expect(status).to have_received(:call).twice
  end

  it 'links the bar to the reasons and says no drift was seen in what was read' do
    stub_status
    get '/woods/units'
    doc = html_response_document

    link = doc.at_css('.bar-fresh a.why')
    expect(link['href']).to eq('/woods/#freshness')
    expect(link.text).to include('no drift seen')
    expect(link['title']).to include('no drift in 120 of 177 recorded files')
  end

  it 'lists the state, coverage, reasons and next steps on the status page' do
    stub_status
    get '/woods'
    row = html_response_document.at_css('#freshness + dd')

    expect(row.text).to include('unknown', 'no drift in 120 of 177 recorded files',
                                'the quick check stopped at its time limit',
                                'files read while Rails booted are unverified')
    expect(row.text).to include('woods-extract full')
  end
end
