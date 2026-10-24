# frozen_string_literal: true

# The Landscape's Components tab (C4 level 3), the board's group control, the
# Hotspots quadrant and forward flow, and the Share menu's text exports (D-25).
RSpec.describe 'Landscape components, charts and sharing', type: :request do
  def page(path)
    get path
    expect(response).to have_http_status(:ok)
    html_response_document
  end

  context 'with Packwerk packages' do
    before { WoodsMap.configuration.index_dir = WoodsMap::PackageIndex.path }

    it 'groups by package, marks the undeclared edge and draws the component diagram' do
      document = page('/woods/landscape/components')
      expect(document.css('.c4boxes.components .c4box b').map(&:text)).to eq(['.', 'packs/posts'])
      expect(document.at_css('[aria-label="Group components by"] a[aria-current=true]').text).to eq('package')
      rows = document.css('table[aria-label="Component relationships"] tbody tr').map do |tr|
        tr.css('td').map do |td|
          td.text.strip
        end
      end
      expect(rows).to include(a_collection_including('.', 'packs/posts', 'undeclared'))
      expect([document.at_css('[data-controller~=diagram] pre').text,
              document.at_css('.c4ladder [aria-current=page]').text])
        .to match([start_with('flowchart LR'), include('L3 · Components')])
    end

    it 'serves the component diagram as Mermaid text for each grouping' do
      get '/woods/landscape/components.mmd', params: { group: 'package' }
      expect(response.media_type).to eq('text/plain')
      expect(response.body).to start_with('flowchart LR').and include('packs/posts')
      expect(response.headers['Content-Disposition']).to include('landscape-components-package.mmd')
    end
  end

  context 'without packages' do
    before { WoodsMap.configuration.index_dir = WoodsMap::LandscapeIndex.path }

    it 'groups by namespace by default and names the package limit when asked for packages' do
      expect(page('/woods/landscape/components').at_css('[aria-label="Group components by"] a[aria-current=true]').text)
        .to eq('namespace')
      empty = page('/woods/landscape/components?group=package')
      expect(empty.at_css('.empty-state').text).to include('No Packwerk packages in this generation')
      get '/woods/landscape/components.mmd', params: { group: 'package' }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('no Packwerk packages')
    end

    it 'groups by the published domain clusters' do
      document = page('/woods/landscape/components?group=cluster')
      expect(document.css('.c4boxes.components .c4box b').map(&:text)).to eq(['Users', '(no cluster)'])
    end

    it 'draws the hotspots quadrant and the forward flow, each with its .mmd text' do
      document = page('/woods/landscape/hotspots')
      texts = document.css('[data-controller~=diagram] pre').map(&:text)
      expect(texts).to include(start_with('quadrantChart'))
      expect(texts).to include(start_with('sankey-beta')) if texts.any? { |t| t.start_with?('sankey-beta') }
      get '/woods/landscape/quadrant.mmd'
      expect(response.body).to start_with('quadrantChart')
      expect(response.headers['X-Woods-Generation']).to eq('1')
    end

    it 'shares the focus URL and the page diagrams as text, without a script' do
      document = page('/woods/landscape/containers')
      share = document.at_css('details.share')
      expect(share.at_css('.sh-url').text).to end_with('/woods/landscape/containers')
      links = share.css('.sh-texts a').pluck('href').map { |href| URI.parse(href).request_uri }
      expect(links).to eq(%w[/woods/landscape.mmd /woods/landscape.dsl /woods/landscape.c4])
      components = page('/woods/landscape/components?group=cluster').at_css('details.share')
      expect(components.at_css('.sh-url').text).to end_with('group=cluster')
      expect(components.css('.sh-texts a').pluck('href').map { |href| URI.parse(href).request_uri })
        .to eq(['/woods/landscape/components.mmd?group=cluster'])
    end

    it 'routes no diagram it does not draw' do
      expect_no_route('/woods/landscape/treemap.mmd')
    end
  end
end
