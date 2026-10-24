# frozen_string_literal: true

RSpec.describe 'Mermaid export from the diagram tools', type: :request do
  it 'gives every diagram panel one copy and one download of the text it draws' do
    { 'schema' => 'user-schema.mmd', 'lifecycle?event=update' => 'user-lifecycle-update.mmd',
      'graph' => 'user-neighbourhood-depth-1.mmd' }.each do |tab, filename|
      get "/woods/units/model/User/#{tab}"
      tools = response.parsed_body.at_css('.dia .dh .tools')
      copy = tools.css('[data-controller="copy"]')
      download = tools.css('[data-controller="download"]')
      expect([copy.size, download.size]).to eq([1, 1])
      expect(copy.first['data-copy-text-value']).to eq(response.parsed_body.at_css('.dia pre.cmd').text)
      expect([download.first['data-download-filename-value'], download.first['data-download-text-value']])
        .to eq([filename, nil])
    end
  end

  it 'carries the text with the tools where no panel draws it: the passage and the impact paths' do
    { '/woods/units/controller/UsersController/passage?action_name=edit' => 'userscontroller-edit-passage.mmd',
      '/woods/impact?focus=User' => 'impact-user.mmd' }.each do |path, filename|
      get path
      download = response.parsed_body.at_css('header [data-controller="download"]')
      expect(download['data-download-filename-value']).to eq(filename)
      expect(download['data-download-text-value']).to start_with('sequenceDiagram').or start_with('flowchart LR')
    end
  end

  it 'needs JavaScript for both tools and leaves the text readable without it' do
    get '/woods/units/model/User/schema'
    tools = response.parsed_body.css('.dia .dh .tools button[data-controller]')
    expect(tools.pluck('data-needs-js')).to all(eq('true'))
    expect(response.body).not_to include('may not render on GitHub')
  end
end
