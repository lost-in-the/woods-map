# frozen_string_literal: true

require 'open3'
require 'tmpdir'

RSpec.describe WoodsMap do
  it 'keeps gutters and folds visible without changing source or links in either lens and mount' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM/CSS regression' unless ENV['WOODS_MAP_BROWSER']

    result = code_scroll_result
    expect(result.fetch('cases')).to eq(16)
    expect(result.fetch('failures')).to eq([])
  end

  def code_scroll_result
    Dir.mktmpdir('woods-map-code-scroll') do |directory|
      fixture = File.join(directory, 'scroll.html')
      File.write(fixture, code_scroll_fixture)
      output, error, status = Open3.capture3(
        ENV.fetch('WOODS_MAP_BROWSER'), '--headless', '--disable-gpu', '--disable-background-networking',
        '--no-first-run', "--user-data-dir=#{File.join(directory, 'profile')}", '--dump-dom', "file://#{fixture}"
      )
      result = Nokogiri::HTML(output).at_css('#result')
      unless status.success? && result && !result.text.empty?
        raise "Code-scroll regression did not produce results: #{error}"
      end

      JSON.parse(result.text)
    end
  end

  def code_scroll_fixture
    root = File.expand_path('..', __dir__)
    styles = %w[tokens.css map.css].map do |name|
      File.read(File.join(root, 'app/assets/stylesheets/woods_map', name))
    end.join("\n")
    runner = File.read(File.join(root, 'spec/javascript/code_scroll_runner.js'))
    "<!doctype html><html lang=\"en\"><head><style id=\"shipped-styles\">#{styles}</style></head>" \
      "<body><pre id=\"result\"></pre><script>#{runner}</script></body></html>"
  end
end
