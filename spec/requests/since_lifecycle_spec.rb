# frozen_string_literal: true

require_relative '../support/code_navigation_index'

RSpec.describe '?since= on the Lifecycle steps', type: :request do
  let(:root) { Pathname.new(Dir.mktmpdir('map-since-lifecycle')) }
  let(:source) { CodeNavigationIndex::POST_SOURCE }
  let(:callback) do
    { 'type' => 'before_save', 'filter' => 'set_slug', 'kind' => 'before', 'conditions' => {}, 'side_effects' => {} }
  end

  def doc
    response.parsed_body
  end

  def publish(callback_entry)
    methods = [CodeNavigationIndex.method('publish_all', 5..9, 'Post', kind: 'singleton'),
               CodeNavigationIndex.method('set_slug', 13..15, 'Post', visibility: 'private')]
    post = { 'identifier' => 'Post', 'type' => 'model', 'file_path' => 'app/models/post.rb', 'source_code' => source,
             'metadata' => { 'methods' => methods, 'callbacks' => [callback_entry] }, 'dependencies' => [],
             'dependents' => [] }
    CodeNavigationIndex::Writer.write_navigation_generation(root, [post])
    WoodsMap.configuration.index_dir = root
  end

  def report(after)
    change = { 'identifier' => 'Post', 'type' => 'model', 'status' => 'modified', 'facets' => ['source'],
               'categories' => ['behaviour'], 'metadata_keys' => [],
               'source_changes' => { 'hunks' => [{ 'before' => after, 'after' => after }], 'added_lines' => 1,
                                     'removed_lines' => 1, 'coverage' => 'complete' } }
    data = { 'schema_version' => 1, 'parameters' => {}, 'coverage' => {}, 'changed' => [change], 'affected' => [],
             'flows' => [], 'unknowns' => [],
             'range' => { 'from' => { 'generation' => 1 }, 'to' => { 'generation' => 1 } } }
    allow(WoodsMap::ImpactRange).to receive(:new)
      .and_return(instance_double(WoodsMap::ImpactRange, state: :available, data: data, message: nil))
  end

  after { FileUtils.remove_entry(root) }

  it "marks a step whose method's published extent holds a changed line" do
    publish(callback)
    report([14, 1])
    get '/woods/units/model/Post/lifecycle', params: { event: 'create', view: 'flowchart', since: 'gen:1' }
    row = doc.at_css('table[aria-label="Steps for create"] tbody tr.chg')
    expect(row.text).to include('set_slug', 'its method changed since the selected generation')
    expect(doc.at_css('.dia').text).to include('class s1 chg')
    expect(doc.css('.seg[aria-label="view"] a').pluck('href')).to all(include('since=gen%3A1'))
  end

  it 'marks a step whose published declaration changed, and nothing outside both' do
    publish(callback.merge('declaration' => { 'line' => 3, 'end_line' => 3 }))
    report([3, 1])
    get '/woods/units/model/Post/lifecycle', params: { event: 'create', since: 'gen:1' }
    expect(doc.at_css('tbody tr.chg').text).to include('its declaration changed')
    report([6, 1])
    get '/woods/units/model/Post/lifecycle', params: { event: 'create', since: 'gen:1' }
    expect(doc.css('tbody tr.chg')).to be_empty
  end
end
