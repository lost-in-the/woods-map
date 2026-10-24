# frozen_string_literal: true

require 'base64'
require 'open3'
require 'tmpdir'

RSpec.describe WoodsMap do
  it 'draws with the vendored Pele and explains a refused text in an inert status line' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']

    expect(browser_result).to include(
      'drawn' => include('drawn' => true, 'svgLabel' => 'drawn diagram', 'svgStyled' => true, 'sourceVisible' => false,
                         'toggleVisible' => true, 'messageVisible' => false, 'error' => nil),
      'refused' => include('drawn' => false, 'sourceVisible' => true, 'toggleVisible' => false,
                           'messageVisible' => true, 'messageChildren' => 0, 'error' => 'limit'),
      'pwned' => false, 'violations' => []
    )
    expect(browser_result.dig('refused', 'message'))
      .to start_with('The diagram could not be drawn: Diagram source is longer than the limit of 50000 characters')
      .and end_with('The Mermaid text is shown instead.')
  end

  def browser_result
    @browser_result ||= Dir.mktmpdir('woods-map-diagram') do |directory|
      fixture = File.join(directory, 'diagram.html')
      File.write(fixture, browser_fixture)
      output, _error, status = Open3.capture3(
        ENV.fetch('WOODS_MAP_BROWSER'), '--headless', '--disable-gpu', '--disable-background-networking',
        '--no-first-run', '--virtual-time-budget=15000', "--user-data-dir=#{File.join(directory, 'profile')}",
        '--dump-dom', "file://#{fixture}"
      )
      result = Nokogiri::HTML(output).at_css('#result')
      raise 'Browser regression did not produce results' unless status.success? && result && !result.text.empty?

      JSON.parse(result.text)
    end
  end

  # The shipped controller, its import line removed, with the vendored Pele mapped in as a data URL:
  # a page opened from a file cannot fetch modules beside it.
  def browser_fixture
    root = File.expand_path('..', __dir__)
    style_root = File.join(root, 'app/assets/stylesheets/woods_map')
    styles = %w[tokens.css map.css].map { |name| File.read(File.join(style_root, name)) }.join("\n")
    pele_source = File.read(File.join(root, 'vendor/javascript/pele.js'))
    pele = "data:text/javascript;base64,#{Base64.strict_encode64(pele_source)}"
    controller = File.read(File.join(root, 'app/javascript/woods_map/controllers/diagram_controller.js'))
                     .sub(/\Aimport[^\n]+\n/, '').sub('export default class', 'class DiagramController')
    runner = File.read(File.join(root, 'spec/javascript/diagram_runner.js'))
    # The engine's policy for styles: no style attribute applies, so Pele's must arrive through the CSSOM.
    policy = "default-src 'none'; style-src 'nonce-spec'; script-src 'nonce-spec' data:; img-src data:"
    "<!doctype html><html lang=\"en\"><head><meta http-equiv=\"Content-Security-Policy\" content=\"#{policy}\">" \
      "<style nonce=\"spec\">#{styles}</style>" \
      "<script type=\"importmap\" nonce=\"spec\">#{JSON.generate(imports: { pele: pele })}</script></head>" \
      "<body><pre id=\"result\"></pre><script nonce=\"spec\">class Controller {}\n#{controller}\n#{runner}</script>" \
      '</body></html>'
  end
end
