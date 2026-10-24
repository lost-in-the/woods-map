# frozen_string_literal: true

require 'json'
require 'open3'
require_relative '../support/large_schema_index'

# The headless render spec (mermaid-diagram-types.md, constraint 4): every
# Mermaid text the map generates from the fixture index is drawn with the
# vendored Pele build in Node, so a renderer change or a Pele upgrade that
# breaks a syntax fails here, not on a page. Node is a test-time tool only;
# the engine never runs it. Without Node the spec skips, unless
# WOODS_MAP_RENDER_SPEC=1 (set in CI) makes a missing Node a failure.
RSpec.describe 'Diagram texts render with the vendored Pele' do # rubocop:disable RSpec/DescribeClass
  let(:root) { File.expand_path('../..', __dir__) }

  def node_available?
    _, status = Open3.capture2e('node', '--version')
    status.success?
  rescue StandardError
    false
  end

  def diagrams
    erds = [FIXTURE_INDEX, WoodsMap::LargeSchemaIndex.path].each_with_index.flat_map do |dir, i|
      WoodsMap::Repository.open(dir) { |repository| erd_diagrams(repository, i.zero? ? 'fixture' : '300') }
    end
    unit_diagrams + landscape_diagrams + history_diagrams + erds
  end

  def unit_diagrams
    WoodsMap::Repository.open(FIXTURE_INDEX) do |repository|
      analysis = repository.graph_analysis
      full = ->(type) { repository.units(type: type).map { |e| repository.unit(e['identifier'], type: e['type']) } }
      full.call('model').flat_map { |unit| model_diagrams(unit, analysis) + state_diagrams(repository, unit) } +
        repository.units.flat_map { |entry| graph_diagrams(repository, entry) } +
        %w[controller mailer].flat_map { |type| full.call(type) }.flat_map { |unit| passage_diagrams(repository, unit) }
    end
  end

  # The container diagram, from the fixture as a Woods with container attribution writes it.
  def landscape_diagrams
    WoodsMap::Repository.open(WoodsMap::LandscapeIndex.path) do |repository|
      landscape = WoodsMap::Landscape.new(repository, system_name: 'Blog "main" <b>')
      hotspots = WoodsMap::Hotspots.new(repository)
      [['flowchart', 'landscape containers', WoodsMap::LandscapeExport.new(landscape).mermaid],
       ['quadrantChart', 'hotspots quadrant', hotspots.quadrant_mermaid],
       ['sankey', 'hotspots forward flow', hotspots.sankey_mermaid],
       ['flowchart', 'landscape context', WoodsMap::LandscapeContext.new(landscape, actors: context_actors).mermaid]] +
        component_diagrams + treemap_diagrams +
        dynamic_diagrams(repository, WoodsMap::DynamicView.new(repository, landscape: landscape))
    end
  end

  def context_actors
    [{ name: 'Author "lead"', description: 'writes <posts>', uses: 'signs in' }, { name: 'Reader' }]
  end

  # Where the code is: by package from package_sizes, and one block from the nodes.
  def treemap_diagrams
    WoodsMap::Repository.open(WoodsMap::PackageIndex.path) do |repository|
      by_package = WoodsMap::Hotspots.new(repository).treemap_mermaid
      allow(repository).to receive(:graph_analysis).and_return({})
      [['treemap', 'treemap by package', by_package],
       ['treemap', 'treemap application', WoodsMap::Hotspots.new(repository).treemap_mermaid]]
    end
  end

  # The Components tab for every grouping, with packages and without.
  def component_diagrams
    [WoodsMap::LandscapeIndex.path, WoodsMap::PackageIndex.path].flat_map do |dir|
      WoodsMap::Repository.open(dir) do |repository|
        WoodsMap::Components::GROUPS.keys.filter_map do |group|
          c = WoodsMap::Components.new(repository, group: group)
          ['flowchart', "components #{File.basename(dir)} #{group}", c.mermaid] unless c.limit
        end
      end
    end
  end

  # The C4 dynamic views (B-23): every model event, an event with async hops
  # into jobs and mail, and every controller passage with its ladder.
  def dynamic_diagrams(repository, view)
    models = repository.units(type: 'model').map { |e| repository.unit(e['identifier'], type: 'model') }
    events = models.flat_map do |unit|
      lifecycle = WoodsMap::Lifecycle.new(unit, dynamic: view)
      lifecycle.chains.keys.map do |event|
        ['flowchart', "dynamic #{unit['identifier']} #{event}", lifecycle.dynamic(event)]
      end
    end
    events + [['flowchart', 'dynamic async', view.lifecycle(models.first, async_steps, 'update')]] +
      passage_dynamic_diagrams(repository, view)
  end

  def async_steps
    effects = { 'jobs_enqueued' => ['ApplicationJob'], 'mailers_triggered' => ['UserMailer'] }
    [WoodsMap::Lifecycle::Step.new(n: 1, type: 'before_save', filter: 'touch "it"', conditions: {}, side_effects: {}),
     WoodsMap::Lifecycle::Step.new(n: 2, type: 'after_update_commit', filter: 'announce', conditions: {},
                                   side_effects: effects)]
  end

  def passage_dynamic_diagrams(repository, view)
    repository.units(type: 'controller').flat_map do |entry|
      unit = repository.unit(entry['identifier'], type: 'controller')
      WoodsMap::Passage.new(repository, unit).actions.map do |action|
        passage = WoodsMap::Passage.new(repository, unit, action: action)
        model = passage.ladder_model
        event = passage.ladder_event
        steps = model && event ? WoodsMap::Lifecycle.new(model).steps(event) : []
        ['flowchart', "dynamic passage #{entry['identifier']}##{action}",
         view.passage(passage, (model if event), steps, (event if model))]
      end
    end
  end

  # Every unit's History exports and the cross-unit timeline, over the
  # fixture's commit table; a fixed clock keeps the window on its commits.
  def history_diagrams
    WoodsMap::Repository.open(FIXTURE_INDEX) do |repository|
      units = repository.units.map { |entry| repository.unit(entry['identifier'], type: entry['type']) }.compact
      set = WoodsMap::HistoryTimeline.new(repository, %w[job:ApplicationJob mailer:MailingListMailer Micropost],
                                          now: history_now)
      units.flat_map { |unit| unit_history_diagrams(repository, unit) } + [['timeline', 'history set', set.mermaid]]
    end
  end

  def history_now
    Time.utc(2026, 10, 18, 12)
  end

  def unit_history_diagrams(repository, unit)
    %w[365d 30d].flat_map do |range|
      history = WoodsMap::HistoryView.new(repository, unit, range: range, now: history_now)
      next [] unless history.any?

      id = "#{unit['type']} #{unit['identifier']} #{range}"
      [['timeline', "history #{id}", history.mermaid('timeline')],
       ['xychart', "history xy #{id}", history.mermaid('xychart')]]
    end
  end

  # Every chunk of the ERD, both groupings and both column modes; the
  # 300-model index exercises chunks at the table budget.
  def erd_diagrams(repository, index)
    erd = WoodsMap::Erd.build(repository)
    WoodsMap::Erd::GROUPINGS.product(WoodsMap::Erd::COLUMN_MODES).flat_map do |by, columns|
      erd.chunks(by).map { |c| ['er', "erd #{index} #{by} #{columns} #{c.number}", erd.mermaid(c, columns: columns)] }
    end
  end

  def model_diagrams(unit, analysis)
    lifecycle = WoodsMap::Lifecycle.new(unit)
    id = unit['identifier']
    [['er', "schema #{id}", WoodsMap::SchemaView.new(unit, graph_analysis: analysis).mermaid]] +
      lifecycle.chains.keys.flat_map do |event|
        [['sequence', "lifecycle #{id} #{event}", lifecycle.mermaid(event)],
         ['flowchart', "lifecycle flowchart #{id} #{event}", lifecycle.flowchart(event)],
         ['swimlane', "lifecycle lanes #{id} #{event}", lifecycle.lanes(event)]]
      end
  end

  def state_diagrams(repository, unit)
    WoodsMap::StateMachineView.for_model(repository, unit['identifier']).map do |machine|
      ['state', "state #{machine.identifier}", machine.mermaid]
    end
  end

  def graph_diagrams(repository, unit)
    id = unit['identifier']
    [1, 2].map do |depth|
      ['flowchart', "neighbourhood #{id} #{depth}", WoodsMap::Neighbourhood.new(repository, id, depth: depth).mermaid]
    end + [['flowchart', "impact #{id}", WoodsMap::BlastRadius.new(repository, focus: id).mermaid]]
  end

  def passage_diagrams(repository, unit)
    WoodsMap::Passage.new(repository, unit).actions.map do |action|
      ['sequence', "passage #{unit['identifier']}##{action}",
       WoodsMap::Passage.new(repository, unit, action: action).mermaid]
    end
  end

  # @return [Hash{String => Hash}] name => what Pele drew, or its error
  def render_all(list)
    input = JSON.generate(list.map { |_, name, text| { name: name, text: text } })
    out, err, status = Open3.capture3('node', File.join(root, 'spec/support/pele_render.mjs'),
                                      File.join(root, 'vendor/javascript/pele.js'), stdin_data: input)
    raise "node failed: #{err}" unless status.success?

    JSON.parse(out).index_by { |r| r['name'] }
  end

  before do
    next if node_available?
    raise 'WOODS_MAP_RENDER_SPEC=1 but node is not on PATH' if ENV['WOODS_MAP_RENDER_SPEC'] == '1'

    skip 'node is not on PATH'
  end

  it 'draws every generated text as the diagram type it declares' do
    list = diagrams
    expect(list.map(&:first).uniq).to contain_exactly('er', 'sequence', 'flowchart', 'swimlane', 'state', 'timeline',
                                                      'xychart', 'quadrantChart', 'sankey', 'treemap')
    results = render_all(list)
    failures = list.filter_map do |type, name, _|
      r = results.fetch(name)
      "#{name}: #{r['error'] || "drew #{r['type']}, expected #{type}"}" unless r['error'].nil? && r['type'] == type
    end
    expect(failures).to be_empty, failures.join("\n")
    expect(results.values).to all(satisfy { |r| r['bytes'].positive? && r['width'].positive? })
  end
end
