# frozen_string_literal: true

require 'open3'
require 'tmpdir'

RSpec.describe 'Sign-in token field', type: :request do
  before { WoodsMap.configuration.token = 'secret-token' }

  let(:remote) { { 'REMOTE_ADDR' => '203.0.113.9' } }

  it 'is not styled as a file tree, which is hidden below 640px' do
    get '/woods/session/new', env: remote
    field = html_response_document.at_css('form.token-form input[name=token]')
    expect(field['class'].split).not_to include('tree')
    expect(field['class'].split).to include('filter')
  end

  it 'stays visible and usable at every width' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']

    get '/woods/session/new', env: remote
    form = html_response_document.at_css('form.token-form').to_html
    [1440, 960, 640, 390].each do |width|
      result = field_result(form, width)
      expect(result).to include('shown' => true, 'overflow' => false), "at #{width}: #{result}"
      expect(result['width']).to be > 100, "at #{width}: #{result}"
    end
  end

  def field_result(form, width)
    Dir.mktmpdir('woods-map-sign-in') do |directory|
      fixture = File.join(directory, 'form.html')
      File.write(fixture, field_fixture(form, width))
      output, _error, status = Open3.capture3(
        ENV.fetch('WOODS_MAP_BROWSER'), '--headless', '--disable-gpu', '--disable-background-networking',
        '--no-first-run', "--user-data-dir=#{File.join(directory, 'profile')}", '--dump-dom', "file://#{fixture}"
      )
      result = Nokogiri::HTML(output).at_css('#result')
      raise 'Browser regression did not produce results' unless status.success? && result && !result.text.empty?

      JSON.parse(result.text)
    end
  end

  def field_fixture(form, width)
    style_root = File.expand_path('../../app/assets/stylesheets/woods_map', __dir__)
    styles = %w[tokens.css map.css].map { |name| File.read(File.join(style_root, name)) }.join("\n")
    probe = <<~JS
      const input = document.querySelector('input[name=token]')
      const box = input.getBoundingClientRect()
      document.getElementById('result').textContent = JSON.stringify({
        shown: input.getClientRects().length > 0 && getComputedStyle(input).display !== 'none',
        width: box.width,
        overflow: document.body.scrollWidth > #{width}
      })
    JS
    "<!doctype html><html lang=\"en\"><head><style>#{styles}</style></head>" \
      "<body class=\"wm page\" data-theme=\"dark\" style=\"width:#{width}px\">#{form}<pre id=\"result\"></pre>" \
      "<script>#{probe}</script></body></html>"
  end
end
