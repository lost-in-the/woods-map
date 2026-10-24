# frozen_string_literal: true

require 'open3'
require 'tmpdir'

# The guide panel's browser half in Chromium (M7): graph units as context,
# the answer tools and the history list, at 1440, 960, 640 and 390.
RSpec.describe 'The guide panel in Chromium', type: :request do
  let(:chats) { Dir.mktmpdir('woods-map-chats') }

  after { FileUtils.rm_rf(chats) }

  it 'takes graph units as context, offers the answer tools and opens the history list' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM regression' unless ENV['WOODS_MAP_BROWSER']

    result = guide_browser_result
    expect(result.fetch('failures')).to eq([])
    expect(result.fetch('cases')).to eq(4)
  end

  def guide_browser_result
    Dir.mktmpdir('woods-map-guide') do |directory|
      fixture = File.join(directory, 'guide.html')
      File.write(fixture, guide_browser_fixture)
      output, error, status = Open3.capture3(
        ENV.fetch('WOODS_MAP_BROWSER'), '--headless', '--disable-gpu', '--disable-background-networking',
        '--no-first-run', '--virtual-time-budget=30000', "--user-data-dir=#{File.join(directory, 'profile')}",
        '--dump-dom', "file://#{fixture}"
      )
      result = Nokogiri::HTML(output).at_css('#result')
      raise "Guide regression did not produce results: #{error}" unless status.success? && result && !result.text.empty?

      JSON.parse(result.text)
    end
  end

  def enable_guide
    WoodsMap.configure do |config|
      config.guide_enabled = true
      config.guide_chats_dir = chats
      config.guide_chat_factory = -> { WoodsMap::FakeGuideChat.new([{ text: 'User has many Posts.' }]) }
    end
  end

  def json_html
    response.parsed_body['html']
  end

  # A conversation answered, left with "new", then reopened: the history list
  # and the thread it returns, as the server renders them; then the Graph
  # tab's panel with an empty current conversation.
  def recorded_fragments
    enable_guide
    post '/woods/guide/questions', params: { question: 'Earlier question',
                                             context: { page: 'graph', type: 'model', identifier: 'User' } }
    get response.parsed_body['stream']
    delete '/woods/guide/conversation'
    get '/woods/guide/conversations'
    history = json_html
    post "/woods/guide/conversations/#{Nokogiri::HTML(history).at_css('button.hrow')['data-guide-id-param']}"
    thread = json_html
    delete '/woods/guide/conversation'
    get '/woods/units/model/User/graph'
    { panel: Nokogiri::HTML(response.body).at_css('aside#wm-guide').to_html, history: history, thread: thread }
  end

  def guide_browser_fixture
    root = File.expand_path('..', __dir__)
    read = ->(path) { File.read(File.join(root, path)) }
    styles = %w[tokens.css map.css].map { |name| read.call("app/assets/stylesheets/woods_map/#{name}") }
    controller = read.call('app/javascript/woods_map/controllers/guide_controller.js')
    data = JSON.generate(recorded_fragments.merge(styles: styles.join("\n"), controller: controller)).gsub('</', '<\\/')
    '<!doctype html><html lang="en"><body><pre id="result"></pre>' \
      "<script>const fixtureData = #{data};\n#{read.call('spec/javascript/guide_runner.js')}</script></body></html>"
  end
end
