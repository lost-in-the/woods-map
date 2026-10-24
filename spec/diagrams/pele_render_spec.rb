# frozen_string_literal: true

require 'json'
require 'open3'

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
    WoodsMap::Repository.open(FIXTURE_INDEX) do |repository|
      analysis = repository.graph_analysis
      full = ->(type) { repository.units(type: type).map { |e| repository.unit(e['identifier'], type: e['type']) } }
      full.call('model').flat_map { |unit| model_diagrams(unit, analysis) } +
        repository.units.flat_map { |entry| graph_diagrams(repository, entry) } +
        %w[controller mailer].flat_map { |type| full.call(type) }.flat_map { |unit| passage_diagrams(repository, unit) }
    end + landscape_diagrams
  end

  # The container diagram, from the fixture as a Woods with container attribution writes it.
  def landscape_diagrams
    WoodsMap::Repository.open(WoodsMap::LandscapeIndex.path) do |repository|
      landscape = WoodsMap::Landscape.new(repository, system_name: 'Blog "main" <b>')
      [['flowchart', 'landscape containers', WoodsMap::LandscapeExport.new(landscape).mermaid]]
    end
  end

  def model_diagrams(unit, analysis)
    lifecycle = WoodsMap::Lifecycle.new(unit)
    id = unit['identifier']
    [['er', "schema #{id}", WoodsMap::SchemaView.new(unit, graph_analysis: analysis).mermaid]] +
      lifecycle.chains.keys.map { |event| ['sequence', "lifecycle #{id} #{event}", lifecycle.mermaid(event)] }
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
    expect(list.map(&:first).uniq).to contain_exactly('er', 'sequence', 'flowchart')
    results = render_all(list)
    failures = list.filter_map do |type, name, _|
      r = results.fetch(name)
      "#{name}: #{r['error'] || "drew #{r['type']}, expected #{type}"}" unless r['error'].nil? && r['type'] == type
    end
    expect(failures).to be_empty, failures.join("\n")
    expect(results.values).to all(satisfy { |r| r['bytes'].positive? && r['width'].positive? })
  end
end
