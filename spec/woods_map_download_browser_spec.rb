# frozen_string_literal: true

require 'open3'
require 'tmpdir'

RSpec.describe WoodsMap do
  it 'saves a panel\'s Mermaid text, or the text it is given, as a .mmd file built in the browser' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM regression' unless ENV['WOODS_MAP_BROWSER']

    type = 'text/plain;charset=utf-8'
    expect(browser_result['files']).to eq(
      [{ 'name' => 'post-schema.mmd', 'attached' => true, 'text' => "erDiagram\n  \"posts\"\n", 'type' => type },
       { 'name' => 'postscontroller-create-passage.mmd', 'attached' => true,
         'text' => "sequenceDiagram\n  A->>B: x\n", 'type' => type }]
    )
    expect(browser_result['leftovers']).to eq(0)
  end

  def browser_result
    @browser_result ||= Dir.mktmpdir('woods-map-download') do |directory|
      fixture = File.join(directory, 'download.html')
      File.write(fixture, browser_fixture)
      output, _error, status = Open3.capture3(
        ENV.fetch('WOODS_MAP_BROWSER'), '--headless', '--disable-gpu', '--disable-background-networking',
        '--no-first-run', '--virtual-time-budget=5000', "--user-data-dir=#{File.join(directory, 'profile')}",
        '--dump-dom', "file://#{fixture}"
      )
      result = Nokogiri::HTML(output).at_css('#result')
      raise 'Browser regression did not produce results' unless status.success? && result && !result.text.empty?

      JSON.parse(result.text)
    end
  end

  # The shipped controller, its import line removed, run against a stub Controller base.
  def browser_fixture
    root = File.expand_path('..', __dir__)
    controller = File.read(File.join(root, 'app/javascript/woods_map/controllers/download_controller.js'))
                     .sub(/\Aimport[^\n]+\n/, '').sub('export default class', 'class DownloadController')
    runner = File.read(File.join(root, 'spec/javascript/download_runner.js'))
    '<!doctype html><html lang="en"><body><pre id="result"></pre>' \
      "<script>class Controller {}\n#{controller}\n#{runner}</script></body></html>"
  end
end
