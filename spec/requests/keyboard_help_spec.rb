# frozen_string_literal: true

RSpec.describe 'Keyboard help', type: :request do
  it 'provides a named dialog and a discoverable button on every framed page' do
    get '/woods/units/model/User'
    dialog = html_response_document.at_css('dialog[aria-labelledby="wm-keyboard-title"]')
    expect(dialog).not_to be_nil
    expect(dialog.text).to include('Keyboard shortcuts', 'File tree', 'Tables and search results', 'Graph', 'Lifecycle')
    expect(html_response_document.at_css('button[aria-controls="wm-keyboard-help"]')['aria-keyshortcuts']).to eq('?')
  end

  it 'does not advertise unimplemented source-line navigation in the status bar' do
    get '/woods/units/model/User'
    expect(html_response_document.at_css('.status').text).not_to include('lines')
    expect(html_response_document.at_css('.status').text).to include('keyboard help')
  end

  it 'lists implemented shortcuts with their focus context' do
    get '/catalog/map'
    dialog = html_response_document.at_css('dialog')
    expect(dialog.text).to include('focused reference', 'tree has focus', 'Shift+E', 'Escape')
    expect(dialog.text).not_to include('j / k lines')
  end
end
