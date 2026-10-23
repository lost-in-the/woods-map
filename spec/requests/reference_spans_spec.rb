# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'digest'

RSpec.describe 'Published reference spans', type: :request do
  let(:source) { "class Caller\n  Widget.call; Widget.call\nend\n" }
  let(:target) { 'Domain::Widget' }
  let(:reference) do
    { 'line' => 2, 'column' => 15, 'length' => 6, 'target' => target, 'target_type' => 'model',
      'kind' => 'constant', 'confidence' => 'verified' }
  end
  let(:metadata) { { 'references' => [reference] } }
  let(:targets) { [unit(target, 'model'), unit(target, 'factory')] }

  before do
    write_generation(1, [owner] + targets)
    publish(1)
    WoodsMap.configuration.index_dir = root
    WoodsMap::FileTree.reset!
  end

  after do
    WoodsMap::FileTree.reset!
    FileUtils.remove_entry(root)
  end

  def root
    @root ||= Pathname.new(Dir.mktmpdir('map-reference-spans'))
  end

  def owner
    unit('Caller', 'model', source: source, metadata: metadata)
  end

  def unit(identifier, type, source: '', metadata: {})
    { 'identifier' => identifier, 'type' => type, 'file_path' => 'app/synthetic.rb',
      'source_code' => source, 'metadata' => metadata, 'dependencies' => [], 'dependents' => [] }
  end

  def publish(number)
    root.join('generation.json').write(JSON.generate('number' => number, 'token' => "synthetic#{number}",
                                                     'payload' => "payloads/gen-#{number}"))
  end

  def write_generation(number, units)
    payload = root.join("payloads/gen-#{number}")
    groups = units.group_by { |record| Woods::MCP::IndexReader::TYPE_TO_DIR.fetch(record['type']) }
    groups.each { |directory, records| write_units(payload.join(directory), records) }
    payload.join('manifest.json').write(JSON.generate('total_units' => units.size,
                                                      'counts' => groups.transform_values(&:size)))
    nodes = units.to_h { |record| [record['identifier'], record.slice('type', 'file_path')] }
    payload.join('dependency_graph.json').write(JSON.generate('nodes' => nodes, 'file_map' => {}))
  end

  def write_units(directory, records)
    FileUtils.mkdir_p(directory)
    directory.join('_index.json').write(JSON.generate(records.map { |record| record.slice('identifier', 'file_path') }))
    records.each do |record|
      identifier = record.fetch('identifier')
      base = identifier.gsub('::', '__').gsub(/[^a-zA-Z0-9_-]/, '_')
      filename = "#{base}_#{Digest::SHA256.hexdigest(identifier)[0, 8]}.json"
      directory.join(filename).write(JSON.generate(record))
    end
  end

  def source_rows
    html_response_document.css('.cv .src')
  end

  def source_links
    source_rows.css('a')
  end

  %w[/woods /catalog/map].each do |mount|
    it "uses the active #{mount} mount and exact published type for a native named link" do
      get "#{mount}/units/model/Caller"
      link = source_links.first
      expect(source_links.size).to eq(1)
      expect(link&.[]('href')).to eq("#{mount}/units/model/Domain::Widget")
      expect(%w[data-target data-type data-kind].map { |attribute| link&.[](attribute) })
        .to eq([target, 'model', 'constant'])
      expect(link&.[]('aria-label')).to include(target, 'model')
    end
  end

  it 'links the second identical spelling without changing the source or its gutters' do
    get '/woods/units/model/Caller'
    expect(source_rows.map(&:text)).to eq(source.lines.map(&:chomp))
    expect(source_rows[1].text.split('Widget')).to eq(['  ', '.call; ', '.call'])
    expect(source_rows[1].at_css('a').xpath('preceding-sibling::node()').text).to eq('  Widget.call; ')
    expect(html_response_document.css('.cv .ln').map(&:text)).to eq(%w[1 2 3])
  end

  it 'leaves normal link activation to the browser and keeps the published-only legend' do
    get '/woods/units/model/Caller'
    expect(source_links.first.attribute_nodes.map(&:name)).not_to include('role', 'tabindex', 'data-action', 'onclick')
    expect(response.body).to include('links: published typed-registry verified constants')
    expect(response.body).not_to include('unmarked: runtime-verified', '○ static reference')
  end

  it 'serves the native reference destination without JavaScript' do
    get '/catalog/map/units/model/Caller'
    get source_links.first['href']
    expect(response).to have_http_status(:ok)
    expect(html_response_document.at_css('h1').text).to eq('Domain::Widgetmodel')
  end

  context 'with a multiline qualified constant after Unicode and a tab' do
    let(:source) { "class Caller\n\t'é'; Domain::\n    Widget.call\nend\n" }
    let(:reference) { super().merge('column' => 7, 'length' => 19) }

    it 'renders balanced native fragments in source order without changing the text' do
      get '/woods/units/model/Caller'
      expect(source_links.map(&:text)).to eq(['Domain::', '    Widget'])
      expect(source_links.map { |link| link.ancestors('.row').first['id'] }).to eq(%w[L2 L3])
      expect(source_links.pluck('href').uniq).to eq(['/woods/units/model/Domain::Widget'])
      expect(source_rows.map(&:text)).to eq(source.lines.map(&:chomp))
    end
  end

  context 'when only the colliding type exists' do
    let(:targets) { [unit(target, 'factory')] }

    it 'leaves the occurrence unlinked instead of choosing the available factory' do
      get '/woods/units/model/Caller'
      expect(response).to have_http_status(:ok)
      expect(source_links).to be_empty
      expect(source_rows.map(&:text)).to eq(source.lines.map(&:chomp))
    end
  end

  [nil, [], {}, 'unavailable', [nil, 'bad', {}]].each do |references|
    context "with unavailable or malformed span metadata #{references.inspect}" do
      let(:metadata) { references.nil? ? {} : { 'references' => references } }

      it 'renders highlighted source without links' do
        get '/woods/units/model/Caller'
        expect(response).to have_http_status(:ok)
        expect(source_links).to be_empty
        expect(source_rows.css('.const').map(&:text)).to include('Widget')
      end
    end
  end

  context 'with malicious source and published target text' do
    let(:source) { "class Caller\n  Widget.call; '<script>alert(1)</script>'\nend\n" }
    let(:target) { 'Domain::Widget" onclick="alert(1)<script>&' }
    let(:reference) { super().merge('column' => 2) }

    it 'escapes source and attributes while keeping the engine-generated route' do
      get '/catalog/map/units/model/Caller'
      expected = WoodsMap::Engine.routes.url_helpers.unit_path(type: 'model', identifier: target,
                                                               script_name: '/catalog/map')
      expect(source_rows.map(&:text)).to eq(source.lines.map(&:chomp))
      expect(source_links.first&.[]('href')).to eq(expected)
      expect(source_links.first&.[]('data-target')).to eq(target)
      expect(source_rows.css('script, [onclick]')).to be_empty
    end
  end

  context 'with annotations and an embedded concern' do
    let(:source) do
      "# Widget is documentation\nclass Caller\n# │ Included from: Synthetic\n#   Widget.call\n" \
        "# ─── End Synthetic ───\n  Widget.call\nend\n"
    end
    let(:metadata) do
      { 'source_line_map' => [[2, 1, 1], [6, 2, 2]],
        'references' => [[1, 2], [4, 4], [6, 2]].map do |line, column|
          reference.merge('line' => line, 'column' => column)
        end }
    end

    %w[written effective].each do |lens|
      it "links only the unchanged annotated file row in the #{lens} lens" do
        get "/woods/units/model/Caller?lens=#{lens}"
        follow_redirect!
        expect(source_links.map(&:text)).to eq(['Widget'])
        expect(source_links.first.ancestors('.row').first['id']).to eq('L2')
        expected = %w[1 2 3] + (lens == 'effective' ? ['c:1'] : [])
        expect(html_response_document.css('.cv .ln').map(&:text)).to eq(expected)
        expect(source_rows.first(3).map(&:text)).to eq(['class Caller', '  Widget.call', 'end'])
      end
    end
  end

  it 'keeps target reads on the pinned generation when publication switches before lookup' do
    write_generation(2, [owner.merge('source_code' => source.sub('call;', 'next;')), unit(target, 'factory')])
    pin_during_target_read
    get '/woods/units/model/Caller'
    expect([source_links.size, source_rows[1].text]).to eq([1, '  Widget.call; Widget.call'])
    expect(response.body).to include('gen 1')
    get '/woods/units/model/Caller'
    expect([source_links.size, source_rows[1].text]).to eq([0, '  Widget.next; Widget.call'])
    expect(response.body).to include('gen 2')
  end

  def pin_during_target_read
    allow(WoodsMap::Repository).to receive(:open).and_wrap_original do |original, &block|
      original.call do |repository|
        allow(repository).to receive(:unit).and_wrap_original do |read, identifier, **options|
          publish(2) if identifier == target
          read.call(identifier, **options)
        end
        block.call(repository)
      end
    end
  end
end
