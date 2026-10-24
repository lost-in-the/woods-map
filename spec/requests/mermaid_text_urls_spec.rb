# frozen_string_literal: true

RSpec.describe 'Mermaid text URLs (D-25)', type: :request do
  before { WoodsMap::Erd.reset! }

  it 'answers each tab with the text its panel draws, as text/plain, with the generation' do
    %w[schema lifecycle?event=update graph?depth=2].each do |tab|
      get "/woods/units/model/User/#{tab}"
      drawn = response.parsed_body.at_css('.dia pre.cmd').text
      get "/woods/units/model/User/#{tab.sub(/\A(\w+)/, '\1.mmd')}"
      expect([response.status, response.media_type, response.body]).to eq([200, 'text/plain', "#{drawn}\n"])
      expect(response.headers['X-Woods-Generation']).to eq('1')
    end
  end

  it 'names the file in the Content-Disposition and serves the passage and the impact paths' do
    get '/woods/units/model/User/schema.mmd'
    expect(response.headers['Content-Disposition'])
      .to eq('inline; filename="user-schema.mmd"; filename*=UTF-8\'\'user-schema.mmd')
    get '/woods/units/controller/UsersController/passage.mmd', params: { action_name: 'edit' }
    expect(response.body).to start_with('sequenceDiagram')
    get '/woods/impact.mmd', params: { focus: 'User' }
    expect(response.body).to start_with('flowchart LR')
  end

  it 'serves each Lifecycle view as linked from its panel' do
    { nil => 'sequenceDiagram', 'flowchart' => 'flowchart TD', 'lanes' => 'swimlane-beta TB' }.each do |view, start|
      get '/woods/units/model/User/lifecycle', params: { event: 'update', view: view }.compact
      drawn = response.parsed_body.at_css('.dia pre.cmd').text
      get response.parsed_body.at_css('.dia a[data-mermaid-url]')['href']
      expect([response.body, response.body.start_with?(start)]).to eq(["#{drawn}\n", true])
    end
  end

  it 'serves a state machine as the lifecycle text of its own unit, linked from the model\'s panel' do
    get '/woods/units/model/User/lifecycle'
    link = response.parsed_body.css('.dia a[data-mermaid-url]').pluck('href').last
    expect(link).to eq('/woods/units/state_machine/User::aasm/lifecycle.mmd')
    get link
    expect(response.body).to start_with('stateDiagram-v2')
  end

  it 'serves an ERD chunk by number with the closed choices' do
    get '/woods/erd'
    expect(response.parsed_body.at_css('.dia a[data-mermaid-url]')['href']).to eq('/woods/erd.mmd?chunk=1')
    get '/woods/erd.mmd', params: { chunk: 1, columns: 'all' }
    expect(response.body).to start_with('erDiagram').and include('datetime created_at')
  end

  it 'refuses a diagram over its budget with 422 and the reason, never a truncated diagram' do
    stub_const('WoodsMap::SchemaView::TABLE_BUDGET', 1)
    get '/woods/units/model/User/schema.mmd'
    expect([response.status, response.media_type]).to eq([422, 'text/plain'])
    expect(response.body).to eq('3 tables is over the ER budget of 1. No diagram is drawn above the budget. ' \
                                "The page lists every one: #{request.base_url}/woods/units/model/User/schema\n")
  end

  it 'answers what has no diagram in plain text' do
    { '/woods/units/model/Nope/schema.mmd' => [404, "No model named Nope.\n"],
      '/woods/units/model/User/passage.mmd' => [404, "A model has no passage.\n"],
      '/woods/impact.mmd' => [400, "Name the focus: /woods/impact.mmd?focus=<identifier>.\n"],
      '/woods/impact.mmd?from=1&to=now' => [404, "A range has no Mermaid text here; Woods publishes its report.\n"],
      '/woods/erd.mmd?chunk=users' => [404, "No chunk users by namespace; there are 1.\n"] }
      .each do |path, (status, body)|
        get path
        expect([response.status, response.media_type, response.body]).to eq([status, 'text/plain', body])
      end
  end

  it 'reads identifiers with dots and slashes, never a .mmd suffix as part of one' do
    get '/woods/units/view_template/users/show.html.erb/graph.mmd'
    expect(response.body).to start_with('flowchart LR')
    get '/woods/units/model/User.mmd'
    expect(response).to have_http_status(:not_found)
  end

  context 'with a token configured' do
    let(:remote) { { 'REMOTE_ADDR' => '203.0.113.9' } }

    before { WoodsMap.configuration.token = 'secret-token' }

    it 'takes the bearer header, and answers 401 in text without it' do
      get '/woods/units/model/User/schema.mmd', env: remote
      expect([response.status, response.media_type]).to eq([401, 'text/plain'])
      expect(response.headers['WWW-Authenticate']).to eq('Bearer realm="Woods Map"')
      get '/woods/units/model/User/schema.mmd', headers: { 'Authorization' => 'Bearer secret-token' }, env: remote
      expect(response.body).to start_with('erDiagram')
    end

    it 'never takes a token from the URL' do
      get '/woods/units/model/User/schema.mmd', params: { token: 'secret-token' }, env: remote
      expect(response).to have_http_status(:unauthorized)
      expect(response.cookies).to be_empty
    end
  end

  it 'refuses a non-loopback request without a token in plain text, leaking nothing' do
    get '/woods/units/model/User/schema.mmd', env: { 'REMOTE_ADDR' => '203.0.113.9' }
    expect([response.status, response.media_type, response.body])
      .to eq([403, 'text/plain', "Woods Map refused the request (token).\n"])
  end
end
