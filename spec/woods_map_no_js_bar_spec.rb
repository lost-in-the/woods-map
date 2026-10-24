# frozen_string_literal: true

require 'open3'
require 'tmpdir'

# Below 960 the site nav and the search live in the ☰ sheet, which needs a
# script. Found by the end-to-end sweep: without JavaScript a phone reader had
# no way to Units, Graph, ERD, Impact or search. The bar the engine renders,
# with the shipped CSS, in a real browser at each width.
RSpec.describe 'The bar without JavaScript', type: :request do
  it 'keeps the site nav and the search box visible at every width' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']

    get '/woods/units/model/User'
    bar = html_response_document.at_css('header.bar').to_html
    nav = html_response_document.css('header.bar nav a').map { |a| a.text.strip }
    results = [1440, 960, 640, 390].index_with { |width| bar_result(bar, width) }
    results.each do |width, result|
      expect(result).to include('nav' => nav, 'search' => true, 'overflow' => false),
                        "at #{width}: #{result}"
    end
  end

  def bar_result(bar, width)
    Dir.mktmpdir('woods-map-no-js-bar') do |directory|
      fixture = File.join(directory, 'bar.html')
      File.write(fixture, bar_fixture(bar, width))
      output, _error, status = Open3.capture3(
        ENV.fetch('WOODS_MAP_BROWSER'), '--headless', '--disable-gpu', '--disable-background-networking',
        '--no-first-run', "--user-data-dir=#{File.join(directory, 'profile')}", '--dump-dom', "file://#{fixture}"
      )
      result = Nokogiri::HTML(output).at_css('#result')
      raise 'Browser regression did not produce results' unless status.success? && result && !result.text.empty?

      JSON.parse(result.text)
    end
  end

  def bar_fixture(bar, width)
    style_root = File.expand_path('../app/assets/stylesheets/woods_map', __dir__)
    styles = %w[tokens.css map.css].map { |name| File.read(File.join(style_root, name)) }.join("\n")
    probe = <<~JS
      const shown = (el) => !!el && el.getClientRects().length > 0 && getComputedStyle(el).visibility !== 'hidden'
      const bar = document.querySelector('header.bar')
      document.getElementById('result').textContent = JSON.stringify({
        nav: [...bar.querySelectorAll('nav a')].filter(shown).map((a) => a.textContent.trim()),
        search: shown(bar.querySelector('input.q')) && bar.querySelector('input.q').getBoundingClientRect().width > 60,
        overflow: document.body.scrollWidth > #{width}
      })
    JS
    "<!doctype html><html lang=\"en\" class=\"no-js\"><head><style>#{styles}</style></head>" \
      "<body class=\"wm page\" data-theme=\"dark\" style=\"width:#{width}px\">#{bar}<pre id=\"result\"></pre>" \
      "<script>#{probe}</script></body></html>"
  end
end
