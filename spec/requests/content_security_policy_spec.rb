# frozen_string_literal: true

RSpec.describe 'Content-Security-Policy', type: :request do
  let(:asset_source) { "http://localhost/woods/assets/#{WoodsMap::Assets.digest}/" }

  # Pages that render every partial family: the frame, tables, detail blocks,
  # trees, steps, diagrams, the passage matrix, the guidelines specimens, the
  # impact lenses and the bare refusal panel.
  let(:pages) do
    %w[
      /woods /woods/units /woods/guidelines /woods/search?q=User /woods/search?q=create&in=code
      /woods/impact /woods/impact?focus=User /woods/impact?focus=User&lens=risks
      /woods/units/model/User /woods/units/model/User/schema /woods/units/model/User/lifecycle
      /woods/units/model/User/graph /woods/units/model/User/history /woods/units/model/User/peek
      /woods/units/controller/UsersController/passage?action_name=edit /woods/files/app/models/user.rb
    ]
  end

  def directives(header = response.headers['Content-Security-Policy'])
    header.to_s.split(';').to_h do |directive|
      name, *sources = directive.split
      [name, sources]
    end
  end

  it 'limits scripts to the digested assets route and this response nonce' do
    get '/woods'
    nonce = response.body[/<script nonce="([^"]+)"/, 1]
    expect(nonce).not_to be_nil
    expect(directives['script-src']).to contain_exactly(asset_source, "'nonce-#{nonce}'")
    expect(response.body.scan(/<script[^>]*>/)).to all(include(%(nonce="#{nonce}")))
    expect(response.body).to include(%(<script type="importmap" nonce="#{nonce}">))
  end

  it 'sends a fresh nonce with every response' do
    2.times { get '/woods' }
    first = directives['script-src'].last
    get '/woods'
    expect(directives['script-src'].last).not_to eq(first)
  end

  it 'sets the strict directives and never allows inline code or eval' do
    get '/woods'
    expect(directives).to include(
      'default-src' => ["'none'"], 'style-src' => [asset_source], 'font-src' => [asset_source],
      'img-src' => ["'self'", 'data:'], 'connect-src' => ["'self'"], 'object-src' => ["'none'"],
      'base-uri' => ["'none'"], 'form-action' => ["'self'"], 'frame-ancestors' => ["'none'"]
    )
    expect(response.headers['Content-Security-Policy']).not_to include('unsafe')
  end

  it 'follows the mount the request arrived through' do
    get '/catalog/map'
    expect(directives['script-src']).to include("http://localhost/catalog/map/assets/#{WoodsMap::Assets.digest}/")
  end

  it 'covers refusals, the session form, JSON and the engine files' do
    WoodsMap.configuration.token = 'secret-token'
    responses = {
      '/woods' => { env: { 'REMOTE_ADDR' => '203.0.113.9' } },
      '/woods/session/new' => {},
      '/woods/graph/neighbourhood?centre=User&type=model' => { headers: { 'Authorization' => 'Bearer secret-token' } },
      "/woods/assets/#{WoodsMap::Assets.digest}/woods_map/application.js" => {}
    }
    responses.each do |path, options|
      get path, **options
      expect(response.headers['Content-Security-Policy']).to include("frame-ancestors 'none'"), path
    end
  end

  it 'leaves host responses outside the mount alone' do
    get '/host/page'
    expect(response.body).to eq('host page')
    expect(response.headers['Content-Security-Policy']).to be_nil
  end

  # The host's global policy, as `config.content_security_policy` in the host
  # application would set it for every request.
  def with_host_policy(extra = {}, &block)
    policy = ActionDispatch::ContentSecurityPolicy.new(&block)
    env = { 'action_dispatch.content_security_policy' => policy, **extra }
    allow(Rails.application).to(receive(:env_config).and_wrap_original { |original| original.call.merge(env) })
  end

  it "keeps the engine policy where the host's middleware would have added its own" do
    with_host_policy { |policy| policy.script_src :self, :unsafe_inline }
    get '/woods'
    expect(response.headers['Content-Security-Policy']).not_to include('unsafe-inline')
    get '/host/page'
    expect(response.headers['Content-Security-Policy']).to eq("script-src 'self' 'unsafe-inline'")
  end

  it 'lets the host amend the policy' do
    WoodsMap.configuration.content_security_policy = lambda do |policy, request|
      policy.report_uri "#{request.script_name}/csp-reports"
    end
    get '/woods'
    expect(directives['report-uri']).to eq(['/woods/csp-reports'])
    expect(directives['frame-ancestors']).to eq(["'none'"])
  end

  it "hands the header and the nonce back to the host's policy when turned off" do
    WoodsMap.configuration.content_security_policy = false
    with_host_policy('action_dispatch.content_security_policy_nonce_generator' => ->(_) { 'host-nonce' }) do |policy|
      policy.script_src :self
    end
    get '/woods'
    expect(response.headers['Content-Security-Policy']).to eq("script-src 'self' 'nonce-host-nonce'")
    expect(response.body).to include('<script type="importmap" nonce="host-nonce">')
  end

  it 'renders no style attribute on any page, so style-src needs no unsafe-inline' do
    pages.each do |path|
      get path
      expect(response).to have_http_status(:ok), path
      expect(response.body).not_to match(/<[^>]+\sstyle=/), path
    end
  end

  it 'renders no style attribute in a refusal or a token form' do
    WoodsMap.configuration.token = 'secret-token'
    get '/woods/session/new'
    expect(response.body).not_to match(/<[^>]+\sstyle=/)
    get '/woods', env: { 'REMOTE_ADDR' => '203.0.113.9' }, headers: { 'Accept' => 'text/html' }
    WoodsMap.configuration.token = nil
    get '/woods', env: { 'REMOTE_ADDR' => '203.0.113.9' }
    expect(response).to have_http_status(:forbidden)
    expect(response.body).not_to match(/<[^>]+\sstyle=/)
  end

  it 'keeps style attributes out of the view and helper sources' do
    root = File.expand_path('../..', __dir__)
    sources = Dir[File.join(root, 'app/views/**/*.erb')] + Dir[File.join(root, 'app/helpers/**/*.rb')]
    offenders = sources.select { |file| File.read(file).match?(/\sstyle=|\bstyle:\s/) }
    expect(offenders.map { |file| file.delete_prefix("#{root}/") }).to eq([])
  end
end
