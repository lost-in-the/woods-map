# frozen_string_literal: true

require_relative '../support/synthetic_index'

# The files sheet's tree: no page carries it; the sheet fetches one
# fragment per generation, cached by the browser, without framework or gem
# source; folded folders hide what is under them.
RSpec.describe 'The files sheet', type: :request do
  include WoodsMap::SyntheticIndex

  let(:root) { Pathname.new(Dir.mktmpdir('woods-map-sheet')) }

  after do
    WoodsMap::FileTree.reset!
    FileUtils.remove_entry(root)
  end

  def generated_index(models: 2000, framework: 600)
    app = Array.new(models) do |i|
      { 'identifier' => "Area#{i % 20}::Widget#{i}", 'type' => 'model',
        'file_path' => "app/models/area_#{i % 20}/widget_#{i}.rb" }
    end
    installed = Array.new(framework) do |i|
      { 'identifier' => "framework/part_#{i}", 'type' => i.even? ? 'rails_source' : 'gem_source',
        'file_path' => "vendor/bundle/ruby/3.3.0/gems/somegem-1.0/lib/part_#{i}.rb" }
    end
    write_synthetic_index(root, 'models' => app, 'rails_source' => installed)
    WoodsMap.configuration.index_dir = root.to_s
    WoodsMap::FileTree.reset!
  end

  it 'keeps the tree out of every page of a generated index of thousands of units' do
    generated_index
    get '/woods'
    expect(response.body.bytesize).to be < 40_000
    expect(html_response_document.css('.tree, a.f')).to be_empty
    expect(html_response_document.at_css('.sheet [data-sheet-target=tree]')['data-src']).to eq('/woods/tree?gen=1')
    get '/woods/units/model/Area1::Widget1'
    expect(html_response_document.css('a.f')).to be_empty
  end

  it 'serves the tree once per generation without framework or gem source' do
    generated_index
    get '/woods/tree', params: { gen: 1 }
    paths = html_response_document.css('a.f').pluck('data-path')
    expect(paths.size).to eq(2000)
    expect(paths.grep(%r{\Avendor/bundle/})).to be_empty
    expect(html_response_document.at_css('.th').text).to include('2000 units')
  end

  it 'folds every folder below the top level and hides what is under a folded folder' do
    generated_index(models: 40, framework: 0)
    get '/woods/tree', params: { gen: 1 }
    rows = html_response_document.css('[data-tree-target=row]')
    open = rows.select { |row| row['aria-expanded'] == 'true' }.pluck('data-path')
    expect(open).to eq(['app'])
    expect(rows.select { |row| row['data-level'].to_i >= 2 }.map { |row| row.key?('hidden') }).to all(be(true))
  end

  it 'lets the browser keep the current generation and revalidate an older URL' do
    get '/woods/tree', params: { gen: 1 }
    expect(response.headers['Cache-Control']).to include('private').and include('max-age=3600')
    etag = response.headers['ETag']
    get '/woods/tree', params: { gen: 1 }, headers: { 'If-None-Match' => etag }
    expect(response).to have_http_status(:not_modified)
    get '/woods/tree', params: { gen: 0 }
    expect(response.headers['Cache-Control']).to include('no-cache')
  end

  it 'gives the sheet the primary nav and no tree on pages without an index' do
    get '/woods/guidelines'
    expect(html_response_document.css('.sheet .sheet-nav a').map(&:text)).to eq(%w[Units Landscape Graph ERD Impact
                                                                                   History Trail])
    expect(html_response_document.at_css('.sheet [data-sheet-target=tree]')).to be_nil
  end
end
