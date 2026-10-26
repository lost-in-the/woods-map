# frozen_string_literal: true

RSpec.describe 'The Share menu', type: :request do
  def doc
    response.parsed_body
  end

  def menu
    doc.at_css('.ident details.share[data-controller="share"]')
  end

  it 'sits in the unit controls before the primary action with the focus URL readable without a script' do
    get '/woods/units/model/User/lifecycle', params: { event: 'update' }
    copy = menu.at_css('[data-share-target="copyUrl"]')
    expect([menu.at_css('summary.btn').text, menu.at_css('.sh-url').text])
      .to eq(['Share ▾', "#{request.base_url}/woods/units/model/User/lifecycle?event=update"])
    expect([copy['data-copy-text-value'], copy.attributes.key?('data-needs-js')])
      .to eq([menu.at_css('.sh-url').text, true])
    expect(menu.xpath('following-sibling::*').first['class']).to include('primary')
  end

  it 'offers the focus URL and no Markdown or JSON report on unit and impact pages (D-25)' do
    get '/woods/units/model/User'
    expect(menu.text).not_to include('Markdown', 'JSON')
    get '/woods/impact', params: { focus: 'User' }
    expect([menu.at_css('.sh-url').text, menu.text.include?('Markdown')])
      .to eq(["#{request.base_url}/woods/impact?focus=User", false])
    get '/woods/impact', params: { mode: 'range' }
    expect(menu.text).not_to include('Markdown', 'JSON')
  end

  it 'leaves the Mermaid list to the page: an empty, hidden slot the script fills from the diagram panels' do
    get '/woods/units/model/User/schema'
    expect(menu.at_css('[data-share-target="diagrams"]')['hidden']).not_to be_nil
    expect(doc.css('.dia [data-diagram-target="source"]').size).to be_positive
  end

  it 'says what the link carries and what it does not, without freezing a generation or hop count' do
    get '/woods/units/model/User/schema'
    note = menu.at_css('.sh-carries')
    expect(note.text).to include('carries this page and its query', 'entry and pins')
    expect(note.text).to include('does not carry notes, a conclusion or questions')
    expect(note.text).to include('not a frozen copy')
  end
end
