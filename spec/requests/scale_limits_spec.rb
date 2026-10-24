# frozen_string_literal: true

# Long lists are paged and large Mermaid text stays at its .mmd route, so no
# page of a large generation carries every row or megabytes of text.
RSpec.describe 'Scale limits', type: :request do
  describe 'the units index' do
    it 'shows the first rows of each type with its exact count and a link to the rest' do
      stub_const('WoodsMap::UnitsIndex::PER_TYPE', 1)
      get '/woods/units'
      section = html_response_document.at_css('section[aria-labelledby="type-model"]')
      expect(section.css('tbody a').map(&:text)).to eq(%w[Micropost])
      expect(section.at_css('h2').text).to include('3')
      expect(section.at_css('.cap').text).to include('The first 1 of 3, by name.')
      expect(section.at_css('.cap a')['href']).to eq('/woods/units?type=model')
    end

    it 'lists one type a page at a time with a pager' do
      stub_const('WoodsMap::UnitsIndex::PER_PAGE', 2)
      get '/woods/units', params: { type: 'model' }
      document = html_response_document
      expect([document.css('main section.sec').size, document.css('main tbody a').map(&:text)])
        .to eq([1, %w[Micropost Relationship]])
      pager = document.at_css('nav.pager')
      expect(pager.text).to include('1 to 2 of 3 model units, page 1 of 2.')
      expect(pager.at_css('a[rel=next]')['href']).to eq('/woods/units?page=2&type=model')
      expect(document.at_css('nav.rail a[aria-current=page]').text).to start_with('model')
    end

    it 'clamps a page past the end to the last page' do
      stub_const('WoodsMap::UnitsIndex::PER_PAGE', 2)
      get '/woods/units', params: { type: 'model', page: '99' }
      expect(html_response_document.css('main tbody a').map(&:text)).to eq(%w[User])
      expect(html_response_document.at_css('nav.pager a[rel=prev]')['href']).to eq('/woods/units?page=1&type=model')
    end

    it 'shows the overview for a type the generation does not hold' do
      get '/woods/units', params: { type: 'nonexistent' }
      expect(response).to have_http_status(:ok)
      expect(html_response_document.css('main section.sec').size).to be > 1
      expect(html_response_document.at_css('nav.pager')).to be_nil
    end
  end

  it 'pages the list equivalent of a graph' do
    stub_const('WoodsMap::Neighbourhood::LIST_PER_PAGE', 1)
    get '/woods/units/model/User/graph'
    list = html_response_document.at_css('section#edge-list')
    expect(list.css('tbody tr').size).to eq(1)
    pager = list.at_css('nav.pager')
    expect(pager.text).to match(/1 to 1 of \d+ edges, page 1 of \d+\./)
    expect(pager.at_css('a[rel=next]')['href']).to end_with('?page=2#edge-list')
  end

  it 'pages the affected units of a blast radius' do
    stub_const('WoodsMap::BlastRadius::LIST_PER_PAGE', 1)
    get '/woods/impact', params: { focus: 'User', depth: 2 }
    pager = html_response_document.at_css('section[aria-labelledby="aff"] nav.pager')
    expect(pager.text).to match(/1 to 1 of \d+ affected units/)
    expect(pager.at_css('a[rel=next]')['href']).to include('focus=User', 'page=2').and end_with('#aff')
  end

  describe 'Mermaid text over the inline budget' do
    before { stub_const('WoodsMap::MermaidExport::INLINE_BYTES', 10) }

    it 'leaves a refused diagram\'s text out of the page, with no copy of a text its .mmd refuses' do
      stub_const('WoodsMap::Neighbourhood::NODE_BUDGET', 0)
      get '/woods/units/model/User/graph'
      document = html_response_document
      panel = document.at_css('#graph-flowchart')
      expect(panel.at_css('pre[data-diagram-target=source]')).to be_nil
      expect(panel.at_css('.dw .cap:not(.refusal)').text)
        .to match(/Its Mermaid text, .+, is not carried in this page\./)
      expect(document.css('button[data-controller=copy][data-mermaid-name]:not([data-pr-comment])')).to be_empty
      expect(panel.at_css('a[data-mermaid-url]')['href']).to start_with('/woods/units/model/User/graph.mmd')
    end

    it 'copies an unbudgeted diagram from its .mmd route' do
      get '/woods/impact', params: { focus: 'User', depth: 2 }
      button = html_response_document.at_css('section[aria-labelledby="chg"] button[data-mermaid-name]')
      expect(button['data-copy-url-value']).to start_with('/woods/impact.mmd?')
      expect(button['data-copy-text-value']).to be_nil
    end
  end

  it 'still carries Mermaid text under the budget' do
    stub_const('WoodsMap::Neighbourhood::NODE_BUDGET', 0)
    get '/woods/units/model/User/graph'
    source = html_response_document.at_css('#graph-flowchart pre[data-diagram-target=source]')
    expect(source.text).to start_with('flowchart')
  end
end
