# frozen_string_literal: true

# A schema 1 range report over the fixture index (generation 1), as
# Woods::Impact::Report.compare would return it: User and a template changed,
# UsersController reached, and a historical unit from generation 0.
module RangeReportFixture
  def range_report_data
    { 'schema_version' => 1, 'range' => range_report_endpoints,
      'parameters' => { 'mode' => 'range', 'depth' => 2, 'types' => nil, 'via' => nil },
      'changed' => range_report_changes, 'affected' => range_report_affected,
      'flows' => [], 'tables' => [], 'commits' => [], 'tests' => [],
      'templates' => [{ 'identifier' => 'users/show.html.erb', 'type' => 'view_template', 'endpoint' => 'to',
                        'generation' => 1, 'evidence' => [{ 'kind' => 'selected_unit' }] }],
      'risks' => [{ 'kind' => 'hub', 'unit' => { 'identifier' => 'User', 'type' => 'model' }, 'endpoint' => 'to',
                    'generation' => 1, 'evidence' => { 'family' => 'hubs', 'artifact' => 'graph_analysis.json' } }],
      'coverage' => { 'complete' => false, 'affected' => 'bounded', 'flows' => 'partial', 'tests' => 'not_computed' },
      'unknowns' => [{ 'kind' => 'flow_index_unavailable', 'endpoint' => 'to', 'generation' => 1 },
                     { 'kind' => 'not_computed', 'feature' => 'commits' }] }
  end

  def range_report_endpoints
    { 'from' => { 'generation' => 1, 'selector' => 'gen:1', 'git_sha' => 'a1b2c3d4e5f6',
                  'manifest_checksum' => 'm-from' },
      'to' => { 'generation' => 1, 'selector' => 'now', 'git_sha' => '9f8e7d6c5b4a', 'manifest_checksum' => 'm-to' } }
  end

  def range_report_changes
    [{ 'identifier' => 'User', 'type' => 'model', 'status' => 'modified', 'facets' => %w[source metadata],
       'categories' => ['behaviour'], 'metadata_keys' => %w[callbacks loc],
       'diff_stats' => { 'source_before' => { 'bytes' => 10, 'lines' => 2 },
                         'source_after' => { 'bytes' => 12, 'lines' => 3 } } },
     { 'identifier' => 'users/show.html.erb', 'type' => 'view_template', 'status' => 'modified',
       'facets' => ['source'], 'categories' => ['template'], 'metadata_keys' => ['instance_variables'] }]
  end

  def range_report_affected
    edge = { 'source' => { 'identifier' => 'UsersController', 'type' => 'controller' },
             'target' => { 'identifier' => 'User', 'type' => 'model' }, 'via' => 'code_reference' }
    [{ 'identifier' => 'UsersController', 'type' => 'controller', 'distance' => 1, 'endpoint' => 'to',
       'generation' => 1, 'weight' => 0.25,
       'paths' => [{ 'root' => { 'identifier' => 'User', 'type' => 'model' }, 'endpoint' => 'to',
                     'generation' => 1, 'edges' => [edge] }] },
     { 'identifier' => 'Gone', 'type' => 'service', 'distance' => 2, 'endpoint' => 'from', 'generation' => 0,
       'weight' => nil, 'paths' => [] }]
  end

  def stub_range_report(data = range_report_data)
    range = instance_double(WoodsMap::ImpactRange, state: :available, data: data, message: nil)
    allow(WoodsMap::ImpactRange).to receive(:new).and_return(range)
    range
  end
end
