# frozen_string_literal: true

RSpec.describe 'Reading settings', type: :request do
  let(:doc) { html_response_document }

  before do
    get '/woods/units/model/User', params: { lens: 'effective' }
    follow_redirect!
  end

  it 'offers a script-only settings tool in the code view that opens the dialog' do
    tool = doc.at_css('.cv .hdr [aria-controls="wm-settings"]')
    expect(tool.text).to eq('settings')
    expect(tool.attributes.keys).to include('data-needs-js', 'aria-haspopup')
    expect(doc.at_css('dialog#wm-settings[aria-labelledby="wm-settings-title"]')).to be_present
  end

  it 'reuses the remembered lens: radios follow the ?lens= links and mark the current lens' do
    radios = doc.css('#wm-settings input[name=lens]')
    expect(radios.to_h { |r| [r['value'], r['data-url']] })
      .to eq('written' => '/woods/units/model/User?lens=written',
             'effective' => '/woods/units/model/User?lens=effective')
    expect(radios.find { |r| r['checked'] }['value']).to eq('effective')
  end

  it 'labels every control and offers the editor presets and a custom template' do
    form = doc.at_css('#wm-settings form')
    expect(form.css('input, select').map { |c| c.ancestors('label').any? }).to all(be(true))
    expect(form.css('select[name=editor] option').pluck('value')).to eq(%w[none vscode cursor idea textmate zed custom])
    expect(form.at_css('[data-settings-target="custom"]')['hidden']).not_to be_nil
  end

  it 'keeps Code at L as the primary action and renders the editor button hidden until a scheme is set' do
    code = doc.at_css('.ident [data-settings-target="code"]')
    editor = doc.at_css('.ident [data-settings-target="editor"]')
    expect(code.text).to eq('Code at L1')
    expect(editor.text).to eq('In editor at L1')
    expect([editor['hidden'], editor['href'], editor['data-file'], editor['data-line']])
      .to eq(['hidden', nil, 'app/models/user.rb', '1'])
  end

  it 'leaves the other tabs without an editor slot' do
    get '/woods/units/model/User/schema'
    expect(doc.at_css('[data-settings-target="editor"], #wm-settings')).to be_nil
    expect(doc.at_css('.ident a.btn.primary').text).to eq('Code at L1')
  end
end
