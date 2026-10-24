# frozen_string_literal: true

require 'open3'
require 'tmpdir'

# Found by the end-to-end sweep after method-level links landed: a reference
# link to `…/PostsController#L48` made the peek fetch `…#L48/peek`, which is
# the unit page itself, so `p` opened nothing.
RSpec.describe WoodsMap do
  it 'builds the peek URL from a reference link: its line as ?line=, no query, the identifier slash kept' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']

    expect(peek_urls).to eq(
      '/woods/units/model/Post' => '/woods/units/model/Post/peek',
      '/woods/units/controller/PostsController#L48' => '/woods/units/controller/PostsController/peek?line=48',
      '/woods/units/model/Post?since=gen%3A1#L3' => '/woods/units/model/Post/peek?line=3',
      '/woods/units/route/GET%20/' => '/woods/units/route/GET%20//peek'
    )
  end

  def peek_urls
    Dir.mktmpdir('woods-map-peek') do |directory|
      fixture = File.join(directory, 'peek.html')
      File.write(fixture, peek_fixture)
      output, _error, status = Open3.capture3(
        ENV.fetch('WOODS_MAP_BROWSER'), '--headless', '--disable-gpu', '--disable-background-networking',
        '--no-first-run', "--user-data-dir=#{File.join(directory, 'profile')}", '--dump-dom', "file://#{fixture}"
      )
      result = Nokogiri::HTML(output).at_css('#result')
      raise 'Browser regression did not produce results' unless status.success? && result && !result.text.empty?

      JSON.parse(result.text)
    end
  end

  def peek_fixture
    source = File.read(File.expand_path('../app/javascript/woods_map/controllers/peek_controller.js', __dir__))
                 .sub(/\Aimport[^\n]+\n/, '').sub('export default class', 'class PeekController')
    hrefs = ['/woods/units/model/Post', '/woods/units/controller/PostsController#L48',
             '/woods/units/model/Post?since=gen%3A1#L3', '/woods/units/route/GET%20/']
    probe = "document.getElementById('result').textContent = JSON.stringify(Object.fromEntries(" \
            "#{hrefs.to_json}.map((href) => [href, PeekController.peekUrl(href)])))"
    '<!doctype html><html lang="en"><body><pre id="result"></pre>' \
      "<script>class Controller {}\n#{source}\n#{probe}</script></body></html>"
  end
end
