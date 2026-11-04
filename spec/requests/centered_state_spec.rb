# frozen_string_literal: true

require_relative '../support/browser_session'

RSpec.describe 'Full-page first-run layout', type: :request do
  before { WoodsMap.configuration.index_dir = "/missing/#{'long-project-name/' * 12}woods" }

  it 'centers the state in the available body and keeps short windows scrollable' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium layout regression' unless ENV['WOODS_MAP_BROWSER']

    get '/woods'
    result = WoodsMap::BrowserSession.run(browser_fixture(response.body))
    expect(result.fetch('cases')).to eq(8)
    expect(result.fetch('failures')).to eq([])
  end

  it 'centers sign-in while keeping its form reachable in short windows' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium layout regression' unless ENV['WOODS_MAP_BROWSER']

    WoodsMap.configuration.token = 'local-test-token'
    get '/woods/session/new', env: { 'REMOTE_ADDR' => '203.0.113.9' }
    result = WoodsMap::BrowserSession.run(browser_fixture(response.body))
    expect(result.fetch('cases')).to eq(8)
    expect(result.fetch('failures')).to eq([])
  end

  # Render the real response with shipped CSS, without network-dependent assets.
  # @param markup [String] server-rendered first-run response
  # @return [String] isolated browser fixture reporting layout measurements
  def browser_fixture(markup)
    styles = %w[tokens.css map.css].map do |name|
      File.read(File.expand_path("../../app/assets/stylesheets/woods_map/#{name}", __dir__))
    end.join("\n")
    page = markup.gsub(%r{<script\b.*?</script>}m, '').gsub(/<link\b[^>]*>/, '')
                 .sub('class="no-js"', 'class="js"').sub('</head>', "<style>#{styles}</style></head>")
    runner = File.read(File.expand_path('../javascript/centered_state_runner.js', __dir__))
    '<!doctype html><html lang="en"><body><pre id="result"></pre>' \
      "<script>const page = #{JSON.generate(page)};\n#{runner}</script></body></html>"
  end
end
