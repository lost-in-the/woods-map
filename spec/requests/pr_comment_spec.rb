# frozen_string_literal: true

require_relative '../support/landscape_index'

# A diagram as a GitHub pull-request comment (D-25 as amended, woods-map#76):
# the panel's ⎘ copy for PR comment, the Share menu's rows and the `.md`
# routes beside every `.mmd` route.
RSpec.describe 'Diagrams as pull-request comments', type: :request do
  before { WoodsMap::Erd.reset! }

  def doc
    response.parsed_body
  end

  def panel_comment
    doc.at_css('.dia .dh .tools button[data-pr-comment]')
  end

  # Fetches the .mmd text, then the .md comment, which stays the response.
  def text_then_comment(mmd)
    get mmd
    text = response.body.chomp
    get mmd.sub('.mmd', '.md')
    text
  end

  # The paths the comment's last line links: the page, then the .mmd text.
  def links(body)
    body.lines.last.scan(/\]\((http[^)]+)\)/).flatten.map { |url| URI(url).path }
  end

  def expected_comment(text, name, page, mmd)
    "```mermaid\n#{text}\n```\n[Woods Map, #{name}, gen 1](#{page}) · [Mermaid text](#{mmd})\n"
  end

  it 'copies the panel\'s text in a mermaid fence with one line linking this view, its generation and its .mmd' do
    get '/woods/units/model/User/lifecycle', params: { event: 'update', token: 'never-shared' }
    drawn = doc.at_css('.dia pre.cmd').text
    base = "#{request.base_url}/woods/units/model/User/lifecycle"
    expect(panel_comment['data-copy-text-value'])
      .to eq(expected_comment(drawn, 'User lifecycle update sequence', "#{base}?event=update",
                              "#{base}.mmd?event=update"))
    expect([panel_comment.text, panel_comment['data-needs-js'], panel_comment['aria-label']])
      .to eq(['⎘ copy for PR comment', 'true',
              'copy for PR comment: User lifecycle update sequence as a GitHub pull-request comment, ' \
              'with a link to this view'])
  end

  it 'offers no comment for a diagram over its drawing budget, as its .mmd answers 422' do
    stub_const('WoodsMap::SchemaView::TABLE_BUDGET', 1)
    get '/woods/units/model/User/schema'
    er = doc.css('.dia').find { |panel| panel.at_css('.dh b').text == 'Entity relationship' }
    expect([er.at_css('[data-pr-comment]'), er.at_css('[data-pr-comment-refusal]')]).to eq([nil, nil])
  end

  it 'says why a text GitHub cannot hold in one comment is not offered, instead of a broken paste' do
    stub_const('WoodsMap::PrComment::LIMIT', 200)
    get '/woods/units/model/User/schema'
    note = doc.at_css('.dia .dh .tools [data-pr-comment-refusal]')
    expect(panel_comment).to be_nil
    expect(note.text).to match(/\Atoo long for a PR comment \(\d[\d,]* of 200 characters\)\z/)
    expect(note['data-pr-comment-refusal'])
      .to match(/\AToo long for a GitHub comment: .* Share the \.mmd URL instead\.\z/)
  end

  context 'with config.public_url' do
    before { WoodsMap.configuration.public_url = 'https://staging.example.com/tools/' }

    it 'starts the focus URL, the .mmd links the Share menu lists and the comment at the public address' do
      get '/woods/units/model/User/schema'
      expect(doc.at_css('.share .sh-url').text).to eq('https://staging.example.com/tools/woods/units/model/User/schema')
      expect(doc.at_css('.dia [data-mermaid-href]')['data-mermaid-href'])
        .to eq('https://staging.example.com/tools/woods/units/model/User/schema.mmd')
      expect(panel_comment['data-copy-text-value'])
        .to include('](https://staging.example.com/tools/woods/units/model/User/schema) · ' \
                    '[Mermaid text](https://staging.example.com/tools/woods/units/model/User/schema.mmd)')
      expect(doc.at_css('.dia a[data-mermaid-url]')['href']).to eq('/woods/units/model/User/schema.mmd')
    end

    it 'links the public address from a .md comment and a 422\'s page too' do
      get '/woods/units/model/User/schema.md'
      expect(response.body.lines.last).to start_with('[Woods Map, User schema, gen 1](https://staging.example.com/tools/woods')
      stub_const('WoodsMap::SchemaView::TABLE_BUDGET', 1)
      get '/woods/units/model/User/schema.mmd'
      expect(response.body).to end_with("every one: https://staging.example.com/tools/woods/units/model/User/schema\n")
    end
  end

  describe 'the .md routes' do
    it 'answer each tab with the panel\'s comment as text/markdown, with the generation and a .md file name' do
      { 'schema' => 'User schema', 'lifecycle?event=update' => 'User lifecycle update sequence',
        'graph?depth=2' => 'User neighbourhood depth 2' }.each do |tab, name|
        get "/woods/units/model/User/#{tab}"
        mmd = doc.at_css('.dia a[data-mermaid-url]')['href']
        text = text_then_comment(mmd)
        expect([response.status, response.media_type, response.headers['X-Woods-Generation']])
          .to eq([200, 'text/markdown', '1'])
        page, text_url = [mmd.sub('.mmd', ''), mmd].map { |path| "#{request.base_url}#{path}" }
        expect(response.body).to eq(expected_comment(text, name, page, text_url))
        expect(response.headers['Content-Disposition']).to include("filename=\"#{name.parameterize}.md\"")
      end
    end

    it 'serve the passage, impact, ERD, cross-unit history and Trail diagrams the same way' do
      %w[/woods/units/controller/UsersController/passage.mmd?action_name=edit /woods/impact.mmd?focus=User
         /woods/erd.mmd?chunk=1 /woods/history.mmd?units[]=model:User /woods/units/model/User/history.mmd
         /woods/trail.mmd?entry=User%40create].each do |mmd|
        get mmd
        text = response.body
        get mmd.sub('.mmd', '.md')
        expect(response).to have_http_status(:ok), mmd
        expect(response.body).to start_with("```mermaid\n#{text}```\n"), mmd
        expect(links(response.body)).to eq([mmd.split('?').first.delete_suffix('.mmd'), mmd.split('?').first]), mmd
      end
    end

    it 'link the page the diagram is on, which opens on the same view' do
      get '/woods/erd.md', params: { chunk: 1 }
      page = response.body.lines.last[/\]\((http[^)]+)\) · /, 1]
      expect(page).to eq("#{request.base_url}/woods/erd?chunk=1")
      get page
      expect(doc.at_css('.dia a[data-mermaid-url]')['href']).to eq('/woods/erd.mmd?chunk=1')
    end

    it 'refuse a diagram over its budget, and a comment over GitHub\'s limit, with 422 and the reason' do
      stub_const('WoodsMap::SchemaView::TABLE_BUDGET', 1)
      get '/woods/units/model/User/schema.md'
      expect([response.status, response.media_type]).to eq([422, 'text/plain'])
      expect(response.body).to start_with('3 tables is over the ER budget of 1.')
      stub_const('WoodsMap::PrComment::LIMIT', 50)
      get '/woods/units/model/User/schema.md', params: { view: 'class' }
      expect([response.status, response.media_type]).to eq([422, 'text/plain'])
      expect(response.body).to match(/\AToo long for a GitHub comment: \d[\d,]* characters, over its limit of 50\./)
    end

    it 'answer what has no diagram, and an unknown unit, in plain text as .mmd does' do
      { '/woods/units/model/Nope/schema.md' => [404, "No model named Nope.\n"],
        '/woods/units/model/User/passage.md' => [404, "A model has no passage.\n"],
        '/woods/impact.md' => [400, "Name the focus: /woods/impact.mmd?focus=<identifier>.\n"] }
        .each do |path, (status, body)|
          get path
          expect([response.status, response.media_type, response.body]).to eq([status, 'text/plain', body]), path
        end
    end

    context 'with a token configured' do
      let(:remote) { { 'REMOTE_ADDR' => '203.0.113.9' } }

      before { WoodsMap.configuration.token = 'secret-token' }

      it 'take the bearer header, answer 401 in text without it and never take a token from the URL' do
        get '/woods/units/model/User/schema.md', env: remote
        expect([response.status, response.media_type]).to eq([401, 'text/plain'])
        get '/woods/units/model/User/schema.md', params: { token: 'secret-token' }, env: remote
        expect([response.status, response.cookies]).to eq([401, {}])
        get '/woods/units/model/User/schema.md', headers: { 'Authorization' => 'Bearer secret-token' }, env: remote
        expect(response.body).to start_with("```mermaid\nerDiagram")
      end
    end

    it 'count against the same rate limit as .mmd, answered in text' do
      WoodsMap.configuration.rate_limit = 1
      get '/woods/units/model/User/schema.mmd'
      get '/woods/units/model/User/schema.md'
      expect([response.status, response.media_type]).to eq([429, 'text/plain'])
      expect(response.headers['Retry-After']).to be_present
    end
  end

  describe 'the Landscape' do
    before { WoodsMap.configuration.index_dir = WoodsMap::LandscapeIndex.path }

    it 'answers the container diagram and each tab diagram as a comment linking the tab that draws it' do
      { '/woods/landscape.md' => '/woods/landscape', '/woods/landscape/context.md' => '/woods/landscape/context',
        '/woods/landscape/quadrant.md' => '/woods/landscape/hotspots',
        '/woods/landscape/mindmap.md' => '/woods/landscape/domains',
        '/woods/landscape/components.md?group=namespace' => '/woods/landscape/components?group=namespace' }
        .each do |md, page|
          get md.sub('.md', '.mmd')
          text = response.body
          get md
          expect([response.status, response.media_type]).to eq([200, 'text/markdown']), md
          expect(response.body).to start_with("```mermaid\n#{text}```\n")
          expect(response.body.lines.last).to include("](#{request.base_url}#{page})"), md
        end
    end
  end
end
