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
end
