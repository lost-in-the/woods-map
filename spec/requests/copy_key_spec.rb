# frozen_string_literal: true

# Every page whose status bar promises `y` marks exactly the tool it names.
COPY_KEY_PROMISES = {
  '/woods/units/model/User/schema' => ['copy Mermaid', '⎘ copy Mermaid'],
  '/woods/units/model/User/lifecycle' => ['copy Mermaid', '⎘ copy Mermaid'],
  '/woods/units/controller/UsersController/passage?action_name=edit' => ['copy Mermaid', '⎘ copy as Mermaid'],
  '/woods/impact?focus=User' => ['copy URL', '⎘ copy focus URL'],
  '/woods/impact?focus=User&lens=risks' => ['copy URL', '⎘ copy focus URL']
}.freeze

RSpec.describe 'The y copy key', type: :request do
  COPY_KEY_PROMISES.each do |path, (promise, tool_text)|
    it "marks the tool #{path} promises (#{promise})" do
      get path
      page = response.parsed_body
      keys = page.css('.status .kbd').map { |kbd| [kbd.text, kbd.parent.text.squish] }
      expect(keys.find { |key, _| key == 'y' }&.last).to eq("y #{promise}")
      tools = page.css('[data-key~="y"][data-copy-text-value]')
      expect(tools.map { |tool| tool.text.strip }).to eq([tool_text])
    end
  end

  it 'never marks the breadcrumb path tool' do
    get '/woods/units/model/User/schema'
    expect(response.parsed_body.at_css('.crumbs [data-copy-text-value]')['data-key']).to be_nil
  end
end
