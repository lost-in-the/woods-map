# frozen_string_literal: true

require_relative 'support/browser_page'
require_relative 'support/history_index'

RSpec.describe 'The sticky diff header in Chromium', type: :request do
  include WoodsMap::BrowserPage
  include ActiveSupport::Testing::TimeHelpers

  let(:root) { WoodsMap::HistoryIndex.build(generations: 3) }
  let(:source_diff) do
    lines = [{ 'op' => ' ', 'before' => 3, 'after' => 3, 'text' => 'end' },
             { 'op' => '+', 'before' => nil, 'after' => 4, 'text' => '  queue_as :default' }]
    instance_double(WoodsMap::SourceDiff, state: :available, status: 'modified', categories: ['behaviour'],
                                          hunks: [{ 'before' => [3, 1], 'after' => [3, 2], 'lines' => lines }],
                                          changes: { 'added_lines' => 1, 'removed_lines' => 0,
                                                     'coverage' => 'complete' })
  end

  before do
    WoodsMap::CommitLedger.reset!
    travel_to Time.utc(2026, 10, 18, 12)
    WoodsMap.configuration.index_dir = root
    record = { 'identifier' => 'ApplicationJob', 'type' => 'job', 'status' => 'modified', 'facets' => ['source'],
               'categories' => ['behaviour'], 'metadata_keys' => [],
               'diff_stats' => { 'source_before' => { 'lines' => 3 }, 'source_after' => { 'lines' => 4 } } }
    range = instance_double(WoodsMap::ImpactRange, state: :available, data: { 'changed' => [record] }, message: nil)
    allow(WoodsMap::ImpactRange).to receive(:new).and_return(range)
    allow(WoodsMap::SourceDiff).to receive(:new).and_return(source_diff)
  end

  after { FileUtils.rm_rf(root) }

  it 'keeps the hunk header and the generation pair in view of a scrolled diff' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']

    get '/woods/units/job/ApplicationJob/history', params: { from: '1', to: '3' }
    expect(run_page(response.body, runner: diff_runner, width: 1440, height: 700))
      .to eq('headerStays' => true, 'pairInHeader' => true, 'scrolled' => true)
  end

  def diff_runner
    <<~JS
      const diff = document.querySelector(".difft")
      const line = diff.querySelector(".dl.add")
      for (let i = 0; i < 80; i++) diff.append(line.cloneNode(true))
      await settle(100)
      diff.scrollTop = diff.scrollHeight
      await settle(100)
      const hunk = diff.querySelector(".dl.hunk")
      report({
        headerStays: Math.abs(hunk.getBoundingClientRect().top - diff.getBoundingClientRect().top) < 2,
        pairInHeader: hunk.textContent.includes("gen 1 → gen 3"),
        scrolled: diff.scrollTop > 0
      })
    JS
  end
end
