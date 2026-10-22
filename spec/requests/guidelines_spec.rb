# frozen_string_literal: true

RSpec.describe 'Guidelines page', type: :request do
  before { get '/woods/guidelines' }

  it 'renders the component boards from the engine partials' do
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('C1 · Tokens').and include('C2 · Table').and include('C3 · Navigation')
    expect(response.body).to include('C4 · Diagrams').and include('C5 · Chrome')
  end

  it 'composes every component from its partial' do
    %w[tbl grouped stpt rail tree dia legend facts status crumbs ident tabs det tgl].each do |css_class|
      expect(response.body).to match(/class="[^"]*\b#{css_class}\b/), "expected a .#{css_class} element"
    end
  end

  it 'wires the Stimulus controllers the design needs' do
    %w[cliff tooltip rows tree sheet copy].each do |controller|
      expect(response.body).to match(/data-controller="[^"]*\b#{controller}\b/), "expected the #{controller} controller"
    end
  end

  it 'renders the glyph vocabulary from the one table (D-20)' do
    WoodsMap::Glyphs::VOCABULARY.each_value { |mark, _meaning, _where| expect(response.body).to include(mark) }
  end

  it 'provides typed filter keys for indexed specimen files and none for unindexed ones' do
    document = html_response_document
    indexed = document.css('.tree .f:not(.unindexed)')
    unindexed = document.css('.tree .f.unindexed')
    expect(indexed).not_to be_empty
    expect(indexed.map { |row| JSON.parse(row['data-owner-keys']) }).to all(satisfy(&:any?))
    expect(unindexed.map { |row| JSON.parse(row['data-owner-keys']) }).to all(eq([]))
  end

  it 'works without a published index' do
    WoodsMap.configuration.index_dir = '/nonexistent/woods'
    get '/woods/guidelines'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('no index')
  end
end
