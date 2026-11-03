# frozen_string_literal: true

require 'tmpdir'

RSpec.describe 'Impact documentation family', type: :request do
  let(:dir) { Dir.mktmpdir('woods-map-doc-impact') }

  before do
    FileUtils.cp_r(File.join(FIXTURE_INDEX, '.'), dir)
    path = File.join(dir, 'payloads/gen-1/dependency_graph.json')
    graph = JSON.parse(File.read(path))
    graph['nodes']['docs/guide.md'] = { 'type' => 'doc', 'file_path' => 'docs/guide.md' }
    graph['reverse_via']['UsersController'] =
      [{ 'source' => 'Micropost', 'source_type' => 'model', 'via' => 'code_reference' }]
    graph['reverse_via']['UsersController'] << { 'source' => 'docs/guide.md', 'source_type' => 'doc',
                                                 'via' => 'documents' }
    File.write(path, JSON.generate(graph))
    WoodsMap.configuration.index_dir = dir
  end

  after { FileUtils.remove_entry(dir) }

  it 'separates docs from recorded dependent counts and coverage claims' do
    get '/woods/impact', params: { focus: 'UsersController', depth: 1 }
    doc = html_response_document
    expect(doc.at_css('#aff').text).to include('1 within depth 1, 1 direct', '1 documentation')
    expect(doc.at_css('table[aria-label="Focus units"]').text).to include('1 typed unit')
    expect(doc.at_css('section[aria-labelledby="docs"]').text).to include('docs/guide.md')
    expect(doc.at_css('section[aria-labelledby="docs"]').text).not_to include('covered by', 'no mapped test')
  end

  it 'keeps no-mapped-test wording for model rows' do
    get '/woods/impact', params: { focus: 'UsersController', depth: 1 }
    expect(html_response_document.at_css('table[aria-label="Affected units"]').text).to include('no mapped test')
  end

  it 'counts docs in the headline when requested' do
    get '/woods/impact', params: { focus: 'UsersController', depth: 1, show: 'with_docs' }
    expect(html_response_document.at_css('#aff').text).to include('2 within depth 1, 2 direct')
  end

  it 'separates docs in the Used by tile' do
    get '/woods/units/controller/UsersController'
    expect(response.body).to include('Used by 1, 1 documentation')
    expect(html_response_document.text).to include('documentation')
  end

  context 'when code and documentation each exceed one page' do
    before do
      path = File.join(dir, 'payloads/gen-1/dependency_graph.json')
      graph = JSON.parse(File.read(path))
      edges = %w[model doc].flat_map do |type|
        301.times.map do |number|
          identifier = "#{type}_impact_#{number.to_s.rjust(3, '0')}"
          graph['nodes'][identifier] = { 'type' => type }
          { 'source' => identifier, 'source_type' => type, 'via' => type == 'doc' ? 'documents' : 'code_reference' }
        end
      end
      graph['reverse_via']['UsersController'] = edges
      File.write(path, JSON.generate(graph))
    end

    def affected_identifiers(page)
      get '/woods/impact', params: { focus: 'UsersController', depth: 1, page: page.to_s }
      html_response_document.css('section[aria-labelledby="aff"] tbody tr:not(.sub) td.id').map(&:text)
    end

    it 'keeps one shared pager and the total affected-row budget' do
      expect(affected_identifiers(1).size).to eq(WoodsMap::BlastRadius::LIST_PER_PAGE)
      pagers = html_response_document.css('nav[aria-label="Affected units pages"]')
      expect(pagers.size).to eq(1)
      expect(pagers.first.text.squish).to include('1 to 300 of 602 affected units, page 1 of 3')
    end

    it 'reaches both families exactly once across the shared pages' do
      pages = (1..3).map { |page| affected_identifiers(page) }
      expect(pages.map(&:size)).to eq([300, 300, 2])
      identifiers = pages.flatten
      expect(identifiers.size).to eq(identifiers.uniq.size)
      expect(identifiers.grep(/^doc_impact_/).size).to eq(301)
      expect(identifiers.grep(/^model_impact_/).size).to eq(301)
    end
  end
end
