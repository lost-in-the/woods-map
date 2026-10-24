# frozen_string_literal: true

RSpec.describe 'Mermaid tools on the diagram panels', type: :request do
  def panel_source
    response.parsed_body.at_css('.dia pre.cmd').text
  end

  it 'gives every diagram panel one copy tool and one .mmd link to the text it draws' do
    { 'schema' => '/woods/units/model/User/schema.mmd',
      'lifecycle?event=update' => '/woods/units/model/User/lifecycle.mmd?event=update',
      'graph?depth=2' => '/woods/units/model/User/graph.mmd?depth=2&direction=both' }.each do |tab, url|
      get "/woods/units/model/User/#{tab}"
      tools = response.parsed_body.at_css('.dia .dh .tools')
      expect(tools.css('[data-controller="copy"]:not([data-pr-comment])').pluck('data-copy-text-value'))
        .to eq([panel_source])
      link = tools.at_css('a[data-mermaid-url]')
      expect([link['href'], link['rel'], link['type']]).to eq([url, 'alternate', 'text/plain'])
    end
  end

  it 'links the passage and the impact paths, which carry Mermaid without a panel' do
    get '/woods/units/controller/UsersController/passage?action_name=edit'
    expect(response.parsed_body.at_css('header a[data-mermaid-url]')['href'])
      .to eq('/woods/units/controller/UsersController/passage.mmd?action_name=edit')
    get '/woods/impact?focus=User&depth=1&lens=changed'
    expect(response.parsed_body.at_css('header a[data-mermaid-url]')['href'])
      .to eq('/woods/impact.mmd?depth=1&focus=User')
  end

  it 'gives every panel exactly one Mermaid copy and one PR-comment copy' do
    %w[/woods/units/model/User/lifecycle /woods/erd /woods/units/model/User/schema].each do |path|
      get path
      bands = response.parsed_body.css('.dia .dh')
      count = ->(selector) { bands.map { |band| band.css(selector).size }.uniq }
      expect(count.call('[data-controller="copy"]:not([data-pr-comment])')).to eq([1]), path
      expect(count.call('[data-pr-comment][data-controller="copy"]')).to eq([1]), path
    end
  end

  it 'marks no generated type, the lanes included, as newer than GitHub\'s Mermaid; copying needs JavaScript' do
    get '/woods/units/model/User/schema'
    buttons = response.parsed_body.css('.dia .dh .tools button[data-controller]')
    expect(buttons.pluck('data-needs-js')).to all(eq('true'))
    expect(response.body).not_to include('may not render on GitHub')
    get '/woods/units/model/User/lifecycle', params: { view: 'lanes' }
    expect(response.body).to include('swimlane-beta')
    expect(response.body).not_to include('may not render on GitHub')
  end
end
