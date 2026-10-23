# frozen_string_literal: true

require 'open3'

RSpec.describe WoodsMap::FileTree do
  let(:controller) { File.expand_path('../../app/javascript/woods_map/controllers/tree_controller.js', __dir__) }
  let(:runner) { File.expand_path('../javascript/tree_filter_runner.js', __dir__) }
  let(:model) { { 'identifier' => 'Report', 'type' => 'model' } }
  let(:factory) { { 'identifier' => 'Report', 'type' => 'factory' } }

  before do
    skip 'Native JavaScriptCore requires macOS; no Node tooling' unless RUBY_PLATFORM.include?('darwin')
  end

  def filtered_rows(owners, query, file_map: owners.transform_values { |rows| rows.pluck('identifier') })
    tree = described_class.new(file_map, {}, owners: owners)
    fixture = JSON.generate(rows: tree.rows.map(&:to_h), queries: Array(query))
    output, error, status = Open3.capture3('/usr/bin/osascript', '-l', 'JavaScript', runner, File.read(controller),
                                           fixture)
    raise error unless status.success?

    JSON.parse(output).index_by { |row| row['path'] }
  end

  it 'counts a multi-file owner once while filtering both contributor paths' do
    rows = filtered_rows({ 'app/report.rb' => [model], 'app/report/query.rb' => [model] }, 'report')
    expect(rows['app']).to include('count' => '1 of 1', 'hidden' => false)
    expect(rows['app/report']).to include('count' => '1 of 1', 'hidden' => false)
  end

  it 'counts every typed collision in a matching multi-owner file exactly once' do
    rows = filtered_rows({ 'app/report.rb' => [model, factory, model] }, 'report')
    expect(rows['app']).to include('count' => '2 of 2', 'hidden' => false)
    expect(rows['app/report.rb']).to include('hidden' => false)
  end

  it 'keeps unresolved-only matches and their directories visible with zero typed owners' do
    rows = filtered_rows({ 'app/report.rb' => [] }, 'report', file_map: { 'app/report.rb' => ['Unknown'] })
    expect(rows['app']).to include('count' => '0 of 0', 'hidden' => false)
    expect(rows['app/report.rb']).to include('hidden' => false, 'filtered' => 'in')
  end

  it 'keeps an unresolved matching branch visible beneath a directory with other typed owners' do
    owners = { 'app/report.rb' => [model], 'app/unresolved/unknown.rb' => [] }
    rows = filtered_rows(owners, 'unknown')
    expect(rows['app']).to include('count' => '0 of 1', 'hidden' => false)
    expect(rows['app/unresolved']).to include('count' => '0 of 0', 'hidden' => false)
    expect(rows['app/unresolved/unknown.rb']).to include('hidden' => false)
  end

  it 'restores the original typed counts when clearing the filter' do
    rows = filtered_rows({ 'app/report.rb' => [model, factory], 'app/other.rb' => [model] }, ['report', ''])
    expect(rows['app']).to include('count' => '2', 'hidden' => false)
    expect(rows['app/other.rb']).to include('hidden' => false)
  end

  it 'hides directories without matching files' do
    rows = filtered_rows({ 'app/report.rb' => [model] }, 'absent')
    expect(rows['app']).to include('hidden' => true)
    expect(rows['app/report.rb']).to include('hidden' => true)
  end
end
