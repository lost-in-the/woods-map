# frozen_string_literal: true

require_relative 'large_schema_index'
require_relative 'trail_index'
require_relative 'state_machine_index'

# Every Mermaid text the map generates from the fixture indexes, as
# [type, name, text]: the type is what the text declares (Pele's name for
# it). The Pele render spec draws them all; the GitHub Mermaid spec parses
# them all with the Mermaid that GitHub renders. Include beside TrailIndex,
# inside an example group (some texts stub a repository read).
module GeneratedDiagrams # rubocop:disable Metrics/ModuleLength -- one catalogue of every generated text
  def diagrams
    erds = [FIXTURE_INDEX, WoodsMap::LargeSchemaIndex.path].each_with_index.flat_map do |dir, i|
      WoodsMap::Repository.open(dir) { |repository| erd_diagrams(repository, i.zero? ? 'fixture' : '300') }
    end
    unit_diagrams + landscape_diagrams + history_diagrams + erds + trail_diagrams + transition_callback_diagrams
  end

  # The Trail's lanes for each kind of entry, and the pinned graph and ERD,
  # over the scenario-2 index (notes/trail.md).
  def trail_diagrams
    WoodsMap::Repository.open(trail_root) do |repository|
      pins = %w[job:NotifySubscribersJob mailer:MailingListMailer model:Post model:User]
      pinned = WoodsMap::PinnedViews.new(repository, WoodsMap::TrailBoard.new(pins: pins).pins)
      entries = %w[NotifySubscribersJob Post@create Post#set_slug MailingListMailer#new_post]
      unless WoodsMap::RepositoryAssembledFlows.capabilities[:model_events]
        entries.reject! { |entry| entry.include?('@') }
      end
      entries.map do |entry|
        ['flowchart', "trail #{entry}", WoodsMap::LifecycleBuilder.new(repository, entry).mermaid]
      end + [['flowchart', 'trail pinned graph', pinned.graph_mermaid],
             ['er', 'trail pinned erd', pinned.erd_mermaid]] +
        entry_lifecycle_diagrams(repository)
    end
  end

  # The Lifecycle tab's entry flows (woods-map#91) on a job, a mailer and a controller action.
  def entry_lifecycle_diagrams(repository)
    [%w[job NotifySubscribersJob], %w[mailer MailingListMailer], %w[controller UsersController]].flat_map do |type, id|
      lifecycle = WoodsMap::EntryLifecycle.new(repository, repository.unit(id, type: type), action: 'create')
      { 'sequence' => 'sequence', 'flowchart' => 'flowchart', 'lanes' => 'flowchart' }.map do |view, drawn|
        [drawn, "entry #{id} #{view}", lifecycle.diagram(view)]
      end
    end
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
       ['flowchart', 'landscape context', WoodsMap::LandscapeContext.new(landscape, actors: context_actors).mermaid],
       ['mindmap', 'domains mindmap', WoodsMap::DomainMindmap.new(repository.graph_analysis['domain_clusters'],
                                                                  system_name: 'Blog (main)').mermaid]] +
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
      changed_step_diagrams + passage_dynamic_diagrams(repository, view)
  end

  # ?since= marks a moved step with `class sN chg` in both node views (E-8).
  def changed_step_diagrams
    steps = async_steps.each_with_index.map { |step, i| i.zero? ? step.dup.tap { |s| s.changed = :method } : step }
    chart = WoodsMap::LifecycleChart.new(steps, 'Post update')
    expect(chart.flowchart).to include('class s1 chg')
    [['flowchart', 'lifecycle flowchart changed', chart.flowchart],
     ['swimlane', 'lifecycle lanes changed', chart.lanes]]
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
    end + noted_erd(erd, index)
  end

  # ?since= draws moved columns with a comment, beside a key's (E-8).
  def noted_erd(erd, index)
    chunk = erd.chunks('namespace').first
    return [] unless chunk

    notes = chunk.tables.index_with do |name|
      erd.table_named(name).columns.first(2).to_h { |c| [c['name'].to_s, 'modified since gen 1'] }
    end
    [['er', "erd #{index} noted", erd.mermaid(chunk, notes: notes)]]
  end

  def model_diagrams(unit, analysis)
    lifecycle = WoodsMap::Lifecycle.new(unit)
    id = unit['identifier']
    [['er', "schema #{id}", WoodsMap::SchemaView.new(unit, graph_analysis: analysis).mermaid],
     ['class', "class #{id}", WoodsMap::SchemaClassDiagram.new(unit).mermaid]] +
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

  # A machine whose transitions carry structured callbacks (woods#796), labelled per transition.
  def transition_callback_diagrams
    unit = StateMachineIndex.instance_method(:machine_unit).bind_call(self, true)
    [['state', 'state with transition callbacks', WoodsMap::StateMachineView.new(unit).mermaid]]
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
end
