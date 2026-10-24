# frozen_string_literal: true

require 'base64'
require 'open3'
require 'tmpdir'

# Runs the shipped graph controller in headless Chromium and reads back what it reports.
module GraphBrowserRun
  module_function

  # @return [Hash] the drawing run, once for every example that reads it
  def drawing
    @drawing ||= result.tap { |run| raise run['error'] if run['error'] }
  end

  # The drawing is timed without virtual time: the runner works synchronously before the
  # load event, when --dump-dom reads the page. The failure path waits on a fetch, so it
  # runs under a virtual time budget instead.
  def result(failure: false)
    Dir.mktmpdir('woods-map-graph') do |directory|
      fixture = File.join(directory, 'graph.html')
      File.write(fixture, fixture_html)
      output, _error, status = Open3.capture3(
        ENV.fetch('WOODS_MAP_BROWSER'), '--headless', '--disable-gpu', '--disable-background-networking',
        '--no-first-run', *(failure ? ['--virtual-time-budget=15000'] : []), '--window-size=1440,900',
        "--user-data-dir=#{File.join(directory, 'profile')}", '--dump-dom', "file://#{fixture}#{'#failure' if failure}"
      )
      result = Nokogiri::HTML(output).at_css('#result')
      raise 'Browser regression did not produce results' unless status.success? && result && !result.text.empty?

      JSON.parse(result.text)
    end
  end

  # The shipped controller, its import line removed, in a module script with the vendored
  # Cytoscape mapped in as a data URL: a page opened from a file cannot fetch modules beside it.
  def fixture_html
    root = File.expand_path('..', __dir__)
    read = ->(path) { File.read(File.join(root, path), encoding: 'UTF-8') }
    styles = %w[tokens.css map.css].map { |name| read.call("app/assets/stylesheets/woods_map/#{name}") }.join("\n")
    cytoscape = Base64.strict_encode64(read.call('vendor/javascript/cytoscape.esm.min.mjs'))
    imports = { cytoscape: "data:text/javascript;base64,#{cytoscape}" }
    controller = read.call('app/javascript/woods_map/controllers/graph_controller.js')
                     .sub(/\Aimport[^\n]+\n/, '').sub('export default class', 'class GraphController')
    "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><style>#{styles}</style>" \
      "<script type=\"importmap\">#{JSON.generate(imports: imports)}</script></head>" \
      "<body><pre id=\"result\"></pre><script type=\"module\">import cytoscape from \"cytoscape\"\n" \
      "class Controller {}\n#{controller}\n#{read.call('spec/javascript/graph_runner.js')}</script></body></html>"
  end
end

# Real Chromium regressions for the Graph tab's canvas (M5). woods-map#7's exit criterion
# is a 300-unit neighbourhood drawn under 500 ms; the testbed's largest depth-2
# neighbourhood has about a hundred units, so the runner generates one at the endpoint's
# limits (300 units, 1,000 edges). The time is reported on every run and enforced when
# WOODS_MAP_GRAPH_BUDGET_MS is set, since a shared machine's load moves it.
RSpec.describe WoodsMap do
  before do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']
  end

  delegate :drawing, to: :GraphBrowserRun

  it 'draws every element of a 300-unit neighbourhood and times the first frame' do
    warn format('graph canvas, 300 units / 1000 edges: first draw %<ms>.1f ms (%<timings>s); radial layout ' \
                '%<radial>.1f ms; calibration loop (5e7 iterations) %<calibration>.1f ms',
                ms: drawing['ms'], radial: drawing['radialMs'], calibration: drawing['calibrationMs'],
                timings: drawing['timings'].map { |key, value| "#{key} #{value.round}" }.join(', '))
    expect(drawing).to include('drawn' => true, 'nodes' => 300, 'edges' => 1000, 'panelVisible' => true,
                               'fallbackVisible' => false, 'layoutsVisible' => true, 'canvases' => be_positive)
    expect(drawing['ms']).to be_positive.and(be <= drawing['wall'])
    # The policy (M8) refuses inline <style>: Cytoscape must not inject its container sheet.
    expect(drawing['injectedStyles']).to eq(0)
    budget = ENV.fetch('WOODS_MAP_GRAPH_BUDGET_MS', nil)
    expect(drawing['ms']).to be < Float(budget) if budget
  end

  it 'moves along the edges with the arrow keys, opens with Enter and returns with Home' do
    expect(drawing).to include('focusSelected' => 'Post', 'handled' => true, 'rightIsDependency' => true,
                               'home' => 'Post')
    expect(drawing['opened']).to contain_exactly(start_with('Generated::Unit'))
    expect(drawing['status']).to include('Post, model, this unit', 'graph_analysis, per identifier')
  end

  it 'lights the edge of the list row in focus and moves between rows with the arrow keys' do
    expect(drawing).to include('lit' => ['e_0'], 'listMoved' => true)
  end

  it 'switches to the radial layout and names the hidden units' do
    expect(drawing).to include('radialPressed' => 'true', 'radialMoved' => true)
    expect(drawing['facts']).to include('300 units', '1000 edges', '40 more units and 100 edges hidden')
  end

  it 'opens units at the paths Rails routes' do
    expect(drawing['url']).to eq('/woods/units/route/GET%20/users/:id/graph?depth=2')
  end

  it 'keeps dragged positions per generation and query, and forgets them on request (A-3)' do
    expect(drawing).to include('restored' => true, 'forgotten' => true)
  end

  it 'tints the units the blast radius reaches by distance and counts those drawn' do
    expect(drawing['tinted']).to include('direct' => ['n_1'], 'transitive' => ['n_2'])
    expect(drawing.dig('tinted', 'facts')).to include('a change here reaches 3 units, 2 drawn')
  end

  it 'fills the units a range report records as changed and names them in the facts' do
    expect(drawing['ranges']).to include('changed' => ['n_1'], 'direct' => ['n_2'])
    expect(drawing.dig('ranges', 'facts')).to include('1 changed and 1 affected in the report, 2 drawn')
  end

  it 'draws the loop of a self edge on the tallest, widest unit' do
    expect(drawing['loop']).to eq('height' => 56, 'wide' => true, 'refused' => false)
  end

  it 'encodes a re-centring identifier as a query value on the full-screen page' do
    expect(drawing['recentre']).to eq('/woods/graph?centre=GET%20%2Fusers%2F%3Aid%3Fx%3D1%26y&type=route&depth=2')
  end

  it 'leaves the flowchart and the list, and says why, when the neighbourhood cannot be fetched' do
    result = GraphBrowserRun.result(failure: true)
    expect(result).to include('panelVisible' => false, 'fallbackVisible' => true, 'messageVisible' => true,
                              'error' => 'error')
    expect(result['message']).to start_with('The interactive graph could not be drawn')
  end
end
