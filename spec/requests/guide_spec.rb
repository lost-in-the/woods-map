# frozen_string_literal: true

require 'tmpdir'

RSpec.describe 'Guide', type: :request do
  let(:chats) { Dir.mktmpdir('woods-map-chats') }
  let(:script) do
    [{ tools: [['lookup', { 'identifier' => 'User' }]] },
     { text: 'User has many Posts. GhostThing is not real.', tokens: [800, 200] }]
  end

  after { FileUtils.rm_rf(chats) }

  def enable_guide(steps = script)
    WoodsMap.configure do |config|
      config.guide_enabled = true
      config.guide_chats_dir = chats
      config.guide_chat_factory = -> { WoodsMap::FakeGuideChat.new(steps) }
    end
  end

  def ask(params = {})
    post '/woods/guide/questions',
         params: { question: 'What is User?',
                   context: { page: 'code', type: 'model', identifier: 'User' } }.merge(params)
  end

  def events(body = response.body)
    body.split("\n\n").filter_map do |block|
      name = block[/^event: (.+)$/, 1]
      data = block[/^data: (.+)$/, 1]
      [name, JSON.parse(data)] if name
    end
  end

  describe 'disabled, the default' do
    it 'shows no Guide button, no panel and no notice' do
      get '/woods/units/model/User'
      expect(response.body).to not_include('guide-toggle').and(not_include('id="wm-guide"'))
                                                          .and(not_include('Guide unavailable'))
    end

    it 'answers no guide route' do
      ask
      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['error']).to eq('guide_unavailable')
    end
  end

  describe 'enabled on a host that cannot run it' do
    before do
      WoodsMap.configuration.guide_enabled = true
      allow(WoodsMap::Guide).to receive(:ruby_supported?).and_return(false)
    end

    it 'shows the notice and a disabled Guide button, and nothing else' do
      get '/woods/units/model/User'
      expect(response.body).to include('Guide unavailable.')
        .and include("RubyLLM 2.1 needs Ruby 3.2 and this host runs #{RUBY_VERSION}")
      expect(html_response_document.at_css('button.guide-toggle')['disabled']).not_to be_nil
      expect(response.body).not_to include('id="wm-guide"')
    end

    it 'answers a question with the same notice' do
      ask
      expect(response.parsed_body['message']).to include('needs Ruby 3.2')
    end

    it 'names the missing gem when Ruby is new enough' do
      allow(WoodsMap::Guide).to receive_messages(ruby_supported?: true, backend: nil)
      get '/woods'
      expect(response.body).to include('Add ruby_llm (2.1 or later) to the host bundle')
    end
  end

  describe 'enabled' do
    before { enable_guide }

    def panel
      html_response_document.at_css('aside#wm-guide')
    end

    def action_labels
      html_response_document.css('#wm-guide .acts .btn').map(&:text)
    end

    it 'renders the closed panel with a Guide button and the page context' do
      get '/woods/units/model/User'
      expect(panel['hidden']).not_to be_nil
      expect(panel.at_css('.ctx').text).to include('User').and include('model')
      expect(panel.at_css('.budget').text).to include('0 of 12').and include('tool calls')
      expect(html_response_document.at_css('button.guide-toggle[aria-controls=wm-guide]')).not_to be_nil
    end

    it 'offers the code page actions, explain-method only once lines are selected' do
      get '/woods/units/model/User'
      expect(action_labels).to eq(['explain this unit', 'explain this method', 'why might this fail?',
                                   'plan a feature here', 'summarise blast radius'])
      expect(panel.at_css('[data-guide-key-param=explain_method]')['disabled']).not_to be_nil
    end

    it 'offers the passage and lifecycle actions on their tabs, and review on impact' do
      get '/woods/units/controller/UsersController/passage?action_name=edit'
      expect(action_labels).to eq(['explain this unit', 'why might this fail?', 'explain this passage'])
      get '/woods/units/model/User/lifecycle'
      expect(action_labels).to include('explain lifecycle')
      get '/woods/impact?focus=User'
      expect(action_labels).to eq(['summarise blast radius', 'review this change'])
    end

    it 'records a question with server-built context in a guide session' do
      ask
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['html']).to include('What is User?').and include('(User)')
      expect(response.cookies[WoodsMap::GuideSession::COOKIE]).to be_present
    end

    it 'streams the answer as server-sent events under the engine policy' do
      ask
      get response.parsed_body['stream']
      expect(response.headers['Content-Type']).to start_with('text/event-stream')
      expect(response.headers['X-Accel-Buffering']).to eq('no')
      expect(response.headers['Content-Security-Policy']).to include("connect-src 'self'")
      expect(events.map(&:first)).to start_with('open').and include('tool', 'delta').and end_with('done')
    end

    it 'finishes with HTML linked only to known identifiers and the budget spent' do
      ask
      get response.parsed_body['stream']
      done = events.last.last
      expect(done['html']).to include('<a href="/woods/units/model/User">User</a>')
      expect(done['html']).to include('GhostThing').and(not_include('GhostThing</a>'))
      expect(done['budget']).to include('tool_calls' => 1, 'session_tokens' => 1000)
    end

    it 'sends the action prompt with the generation, the unit and its facts, never source' do
      prompts = []
      WoodsMap.configuration.guide_chat_factory = lambda {
        WoodsMap::FakeGuideChat.new([{ text: 'ok' }]).tap { |chat| prompts << chat }
      }
      ask(action_key: 'why_fail', question: '',
          context: { page: 'code', type: 'model', identifier: 'User', lines: '3-4' })
      get response.parsed_body['stream']
      prompt = prompts.last.messages.first.content
      expect(prompt).to include('Why might this fail?').and include('- unit: User (model)')
        .and include('selected lines: L3–L4')
      expect(prompt).to match(/Woods generation \d+/)
    end

    it 'drops context the generation does not know' do
      ask(context: { page: 'code', type: 'model', identifier: 'Nope', focus: 'Ghost,User' })
      expect(response.parsed_body['html']).not_to include('Nope')
    end

    it 'streams a turn once; a reconnect gets the finished answer again' do
      ask
      stream = response.parsed_body['stream']
      get stream
      get stream
      expect(events.map(&:first)).to eq(%w[open done])
    end

    it 'refuses an unknown action, an empty question and explain-method without lines' do
      ask(action_key: 'delete_everything')
      expect(response).to have_http_status(:unprocessable_entity)
      ask(question: '  ')
      expect(response).to have_http_status(:unprocessable_entity)
      ask(action_key: 'explain_method', question: '')
      expect(response.parsed_body['message']).to eq('Select lines in the code first.')
    end

    it 'shows the conversation on the next page, linked against that generation' do
      ask
      get response.parsed_body['stream']
      get '/woods/units/model/User'
      thread = html_response_document.at_css('#wm-guide .thread')
      expect(thread.text).to include('What is User?').and include('1 tool call')
      expect(thread.at_css('.call').text).to include('lookup').and include('(User)')
      expect(thread.at_css('.text a[href="/woods/units/model/User"]')).not_to be_nil
    end

    it 'starts a new conversation but keeps the session spend' do
      ask
      get response.parsed_body['stream']
      delete '/woods/guide/conversation'
      expect(response).to have_http_status(:no_content)
      get '/woods/units/model/User'
      expect(html_response_document.css('#wm-guide .thread .msg')).to be_empty
      expect(html_response_document.at_css('#wm-guide .budget').text).to include('1.0k of 60.0k')
    end

    it 'stops an answer on request' do
      enable_guide([{ text: 'one' }, { text: 'two' }])
      ask
      id = response.parsed_body['id']
      post "/woods/guide/questions/#{id}/cancel"
      expect(response).to have_http_status(:no_content)
      get "/woods/guide/questions/#{id}/stream"
      expect(events.last.first).to eq('cancelled')
    end

    context 'when the session budget is spent' do
      before do
        WoodsMap.configuration.guide_token_budget = 900
        ask
        get response.parsed_body['stream']
      end

      it 'stops the answer that spent it and refuses the next question' do
        expect(events.last.first).to eq('limited')
        ask
        expect(response).to have_http_status(:too_many_requests)
        expect(response.parsed_body['error']).to eq('budget')
      end

      it 'shows the exhausted state with the question box disabled' do
        get '/woods/units/model/User'
        expect(panel.text).to include('Budget spent.')
        expect(panel.at_css('textarea')['disabled']).not_to be_nil
      end
    end

    describe 'the history list' do
      def answered(question)
        ask(question: question)
        get response.parsed_body['stream']
      end

      def history_list
        get '/woods/guide/conversations'
        Nokogiri::HTML(response.parsed_body['html'])
      end

      def two_conversations
        answered('What is User?')
        delete '/woods/guide/conversation'
        answered('And Post?')
      end

      it 'lists this session\'s conversations, the current one first' do
        two_conversations
        list = history_list
        expect(list.css('.hrow b').map(&:text)).to eq(['And Post?', 'What is User?'])
        expect(list.at_css('.hrow.cur[aria-current=true]').text).to include('current').and include('1 question')
      end

      it 'opens an earlier conversation, linked against the generation, and keeps it current on the next page' do
        two_conversations
        post "/woods/guide/conversations/#{history_list.at_css('button.hrow')['data-guide-id-param']}"
        thread = Nokogiri::HTML(response.parsed_body['html'])
        expect(thread.text).to include('What is User?').and(not_include('And Post?'))
        expect(thread.at_css('.text a[href="/woods/units/model/User"]')).not_to be_nil
        get '/woods/units/model/User'
        expect(html_response_document.at_css('#wm-guide .thread').text).to include('What is User?')
      end

      it 'says there is nothing yet, and offers the history button in the panel header' do
        expect(history_list.text).to include('No conversations yet in this browser session')
        get '/woods/units/model/User'
        toggle = html_response_document.at_css('#wm-guide .gh button[aria-controls=wm-guide-history]')
        expect(toggle.text).to eq('history')
        expect(html_response_document.at_css('#wm-guide-history[hidden]')).not_to be_nil
      end

      it 'refuses an unknown conversation' do
        post '/woods/guide/conversations/0123456789abcdef'
        expect(response).to have_http_status(:not_found)
      end

      it 'refuses to switch while an answer is pending' do
        two_conversations
        earlier = history_list.at_css('button.hrow')['data-guide-id-param']
        ask(question: 'still pending')
        post "/woods/guide/conversations/#{earlier}"
        expect(response).to have_http_status(:conflict)
        expect(response.parsed_body['message']).to include('Stop it first')
      end
    end

    describe 'drafting an issue from an answer' do
      let(:prompts) { [] }
      let(:source) do
        WoodsMap.configuration.guide_chat_factory = lambda {
          WoodsMap::FakeGuideChat.new([{ text: "# Notify without retry\n\nUser has many Posts." }]).tap { |c| prompts << c }
        }
        ask
        id = response.parsed_body['id']
        get response.parsed_body['stream']
        id
      end

      def draft
        ask(action_key: 'draft_issue', question: '', source: source)
        get response.parsed_body['stream']
        events.last.last
      end

      it 'offers copy and draft-an-issue under a finished answer' do
        id = source
        get '/woods/units/model/User'
        tools = html_response_document.at_css("#wm-guide .answer[data-turn='#{id}'] .answer-tools")
        expect(tools.css('button').map(&:text)).to eq(['⎘ copy', 'draft an issue'])
        expect(tools.at_css('[data-guide-source-param]')['data-guide-source-param']).to eq(id)
      end

      it 'drafts from that answer, which the prompt carries' do
        expect(draft).to include('kind' => 'issue', 'source' => source)
        user = prompts.last.messages.select { |message| message.role == :user }.last
        expect(user.content).to include('Draft an issue').and include('# Notify without retry')
      end

      it 'offers the draft as text to copy only, and posts nothing' do
        draft
        get '/woods/units/model/User'
        issue = html_response_document.css('#wm-guide .answer.issue').last
        expect(issue.at_css('.who').text).to include('issue draft')
        expect(issue.css('.answer-tools button').map(&:text)).to eq(['⎘ copy issue'])
        expect(issue.at_css('.answer-tools').text).to include('the map posts nothing')
      end

      it 'refuses a draft without a finished answer of this conversation' do
        ask(action_key: 'draft_issue', question: '')
        expect(response.parsed_body['message']).to eq('Pick a finished answer to draft the issue from.')
        ask
        ask(action_key: 'draft_issue', question: '', source: response.parsed_body['id'])
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe 'units selected on a graph' do
      it 'offers the graph actions on the Graph tab, the selection one waiting for a selection' do
        get '/woods/units/model/User/graph'
        expect(action_labels).to eq(['explain this unit', 'summarise blast radius', 'explain the selected units'])
        expect(panel.at_css('[data-guide-key-param=explain_selection]')['disabled']).not_to be_nil
        expect(html_response_document.at_css('[data-controller~=graph]')['data-graph-pick-value']).to eq('true')
      end

      it 'offers them on the full-screen graph, with its centre as context' do
        get '/woods/graph?centre=User&type=model'
        expect(action_labels).to include('explain the selected units')
        expect(panel.at_css('.ctx').text).to include('User')
      end

      it 'sends the selected units the generation has, typed, and drops the rest' do
        prompts = []
        WoodsMap.configuration.guide_chat_factory = lambda {
          WoodsMap::FakeGuideChat.new([{ text: 'ok' }]).tap { |chat| prompts << chat }
        }
        ask(action_key: 'explain_selection', question: '',
            context: { page: 'graph', type: 'model', identifier: 'User',
                       nodes: ['model:Micropost', 'model:Ghost', 'controller:Micropost', 'nonsense'] })
        expect(response.parsed_body['html']).to include('(User, 1 graph unit)')
        get response.parsed_body['stream']
        prompt = prompts.last.messages.first.content
        expect(prompt).to include('- units selected on the graph: Micropost (model)')
        expect(prompt).not_to include('Ghost')
      end

      it 'refuses the selection action with nothing selected' do
        ask(action_key: 'explain_selection', question: '',
            context: { page: 'graph', type: 'model', identifier: 'User' })
        expect(response.parsed_body['message']).to start_with('Select units on the graph first')
      end

      it 'leaves picking off while the guide is off' do
        WoodsMap.configuration.guide_enabled = false
        get '/woods/units/model/User/graph'
        expect(html_response_document.at_css('[data-controller~=graph]')['data-graph-pick-value']).to be_nil
      end
    end

    describe 'the Trail hand-off' do
      let(:board_context) do
        { page: 'trail', entry: 'UsersController#show', pins: ['model:User', 'model:Ghost'], gen: '1', hops: '2' }
      end

      def finished_on(context, text: 'User has many Micropost records.')
        WoodsMap.configuration.guide_chat_factory = -> { WoodsMap::FakeGuideChat.new([{ text: text }]) }
        ask(context: context)
        get response.parsed_body['stream']
        events.last.last
      end

      it 'offers explain this investigation on a board, with its entry and pins as context' do
        get '/woods/trail?entry=UsersController%23show&pin[]=model:User'
        expect(action_labels).to eq(['explain this investigation'])
        expect(panel.at_css('.ctx').text).to include('UsersController#show').and include('pinned')
        expect(panel.css('input[name="context[pins][]"]').pluck('value')).to eq(['model:User'])
      end

      it 'sends the board the generation knows to the investigation prompt' do
        prompts = []
        WoodsMap.configuration.guide_chat_factory = lambda {
          WoodsMap::FakeGuideChat.new([{ text: 'ok' }]).tap { |chat| prompts << chat }
        }
        ask(action_key: 'explain_investigation', question: '', context: board_context)
        get response.parsed_body['stream']
        prompt = prompts.last.messages.first.content
        expect(prompt).to include('- trail entry: UsersController#show, async hop budget 2')
          .and include('- pinned on the trail board: User (model)')
        expect(prompt).not_to include('Ghost')
      end

      it 'links pin to the board asked on, with the cited units added, and open as investigation' do
        trail = finished_on(board_context)['trail']
        expect(CGI.unescape(trail['pin'])).to start_with('/woods/trail?')
          .and include('entry=UsersController#show').and include('pin[]=model:User')
          .and include('pin[]=model:Micropost').and include('gen=1')
        expect(CGI.unescape(trail['investigation'])).to include('pin[]=model:User').and include('pin[]=model:Micropost')
      end

      it 'offers only open as investigation off a board, and both again on the next page' do
        expect(finished_on({ page: 'code', type: 'model', identifier: 'User' })['trail'].keys).to eq(['investigation'])
        get '/woods/units/model/User'
        tools = html_response_document.at_css('#wm-guide .answer .answer-tools')
        expect(tools.css('a.tool, button.tool').map(&:text)).to eq(['open as investigation', '⎘ copy',
                                                                    'draft an issue'])
      end
    end

    it 'rate-limits questions like the other expensive endpoints' do
      WoodsMap.configuration.rate_limit = 1
      ask
      ask
      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body['error']).to eq('rate_limited')
    end

    it 'says a provider failure in the stream' do
      WoodsMap.configuration.guide_chat_factory = -> { raise ArgumentError, 'Missing API key' }
      ask
      get response.parsed_body['stream']
      expect(events.last).to match(['failed', include('error' => 'ArgumentError: Missing API key')])
    end

    it 'keeps one session from reading another' do
      ask
      stream = response.parsed_body['stream']
      cookies.delete(WoodsMap::GuideSession::COOKIE)
      get stream
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'the gate' do
    before { enable_guide }

    let(:remote) { { 'REMOTE_ADDR' => '203.0.113.9' } }

    it 'refuses a non-loopback request without the token' do
      post '/woods/guide/questions', params: { question: 'x' }, env: remote
      expect(response).to have_http_status(:forbidden)
    end

    it 'answers a non-loopback request that carries the token' do
      WoodsMap.configuration.token = 'secret-token'
      post '/woods/guide/questions', params: { question: 'x' }, headers: { 'Authorization' => 'Bearer secret-token' },
                                     env: remote
      expect(response).to have_http_status(:ok)
    end

    it 'refuses a cross-origin question' do
      post '/woods/guide/questions', params: { question: 'x' }, headers: { 'Origin' => 'https://evil.example' }
      expect(response).to have_http_status(:forbidden)
    end
  end
end
