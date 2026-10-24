# frozen_string_literal: true

require 'json'
require 'open3'
require 'tmpdir'
require 'zlib'
require 'digest'
require_relative '../support/generated_diagrams'
require_relative '../support/github_mermaid_vendor'

# GitHub draws a ```mermaid block in an issue or a pull request with its own
# Mermaid (woods-map#76). This spec parses every text the map generates, the
# same set the Pele render spec draws, with that exact Mermaid build, vendored
# under spec/vendor/github_mermaid for the spec only: Node is a test-time
# tool and the engine never runs it. A text GitHub's Mermaid would refuse
# fails here instead of in a reviewer's comment. With WOODS_MAP_BROWSER set,
# the same build also renders every text in Chromium, as GitHub's page does.
# Without Node the spec skips, unless WOODS_MAP_RENDER_SPEC=1 (set in CI).
RSpec.describe 'Diagram texts parse with the Mermaid GitHub renders' do # rubocop:disable RSpec/DescribeClass
  include TrailIndex
  include GeneratedDiagrams

  def node_available?
    _, status = Open3.capture2e('node', '--version')
    status.success?
  rescue StandardError
    false
  end

  # @return [Hash] {'version' => String, 'results' => {name => {'ok', 'detected', 'error'}}}
  def parse_all(list)
    input = JSON.generate(list.map { |_, name, text| { name: name, text: text } })
    out, err, status = Open3.capture3('node', File.expand_path('../support/github_mermaid_parse.mjs', __dir__),
                                      GithubMermaidVendor::BUILD, GithubMermaidVendor::DOM, stdin_data: input)
    raise "node failed: #{err}" unless status.success?

    parsed = JSON.parse(out)
    parsed.merge('results' => parsed['results'].index_by { |r| r['name'] })
  end

  before do
    next if node_available?
    raise 'WOODS_MAP_RENDER_SPEC=1 but node is not on PATH' if ENV['WOODS_MAP_RENDER_SPEC'] == '1'

    skip 'node is not on PATH'
  end

  it 'vendors the unmodified build of the version MermaidExport names' do
    build = Zlib.gunzip(File.binread(GithubMermaidVendor::BUILD))
    expect(Digest::SHA256.hexdigest(build)).to eq(GithubMermaidVendor::BUILD_SHA256)
    expect(parse_all([])['version']).to eq(WoodsMap::MermaidExport::GITHUB_MERMAID_VERSION)
  end

  it 'parses every generated text as the type it declares, the swimlanes included' do
    list = diagrams
    expect(list.map(&:first).uniq).to match_array(GithubMermaidVendor::DETECTED.keys)
    results = parse_all(list)['results']
    failures = list.filter_map do |type, name, _|
      r = results.fetch(name)
      "#{name}: #{r['error'] || "parsed as #{r['detected']}, expected #{GithubMermaidVendor::DETECTED[type]}"}" unless
        r['ok'] && r['detected'] == GithubMermaidVendor::DETECTED.fetch(type)
    end
    expect(failures).to be_empty, failures.join("\n")
  end

  it 'still rejects what it should: a broken text, and every keyword marked newer than GitHub' do
    broken = [['flowchart', 'broken flowchart', "flowchart TD\n  a[\"x\" --> b"],
              ['swimlane', 'broken lanes', "swimlane-beta TB\n  subgraph l [\"a\"]\n    s1[\"x\"]"]]
    newer = WoodsMap::MermaidExport::NEWER_THAN_GITHUB.map { |keyword| ['newer', keyword, "#{keyword}\n  a"] }
    results = parse_all(broken + newer)['results']
    expect(results.values.pluck('ok')).to all(be(false))
    expect(newer.map { |_, name, _| results.dig(name, 'error') }).to all(start_with('No diagram type detected'))
  end

  it 'renders every generated text in Chromium with that build' do
    skip 'Set WOODS_MAP_BROWSER to render with GitHub\'s Mermaid in Chromium' unless ENV['WOODS_MAP_BROWSER']

    list = diagrams
    results = browser_render(list)
    failures = list.filter_map { |_, name, _| "#{name}: #{results.dig(name, 'error')}" unless results.dig(name, 'ok') }
    expect(results.size).to eq(list.size)
    expect(failures).to be_empty, failures.join("\n")
  end

  # Draws each text with mermaid.render in a headless page, strict security as
  # on GitHub; a text that draws Mermaid's error diagram counts as a failure.
  def browser_render(list)
    Dir.mktmpdir('woods-map-github-mermaid') do |directory|
      build = File.join(directory, 'mermaid.min.js')
      File.binwrite(build, Zlib.gunzip(File.binread(GithubMermaidVendor::BUILD)))
      page = File.join(directory, 'render.html')
      File.write(page, render_page(list))
      output, error, status = Open3.capture3(
        ENV.fetch('WOODS_MAP_BROWSER'), '--headless', '--disable-gpu', '--disable-background-networking',
        '--no-first-run', '--allow-file-access-from-files', '--virtual-time-budget=600000',
        "--user-data-dir=#{File.join(directory, 'profile')}", '--dump-dom', "file://#{page}"
      )
      result = Nokogiri::HTML(output).at_css('#result')
      raise "Mermaid render did not produce results: #{error}" unless status.success? && result && !result.text.empty?

      JSON.parse(result.text).index_by { |r| r['name'] }
    end
  end

  def render_page(list)
    data = JSON.generate(list.map { |_, name, text| { name: name, text: text } }).gsub('</', '<\\/')
    <<~HTML
      <!doctype html><html lang="en"><body><pre id="result"></pre>
      <script src="mermaid.min.js"></script>
      <script>
      (async () => {
        mermaid.initialize({ startOnLoad: false, securityLevel: "strict" })
        const out = []
        let n = 0
        for (const { name, text } of #{data}) {
          try {
            const { svg } = await mermaid.render(`d${n++}`, text)
            const error = /aria-roledescription="error"|Syntax error in text/.test(svg) ? "drew the error diagram" : null
            out.push({ name, ok: !error, error })
          } catch (e) { out.push({ name, ok: false, error: String(e && e.message || e).slice(0, 300) }) }
        }
        document.getElementById("result").textContent = JSON.stringify(out)
      })().catch((e) => { document.getElementById("result").textContent = JSON.stringify([{ name: "runner", ok: false, error: String(e) }]) })
      </script></body></html>
    HTML
  end
end
