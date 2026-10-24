# frozen_string_literal: true

require 'open3'
require 'tmpdir'

RSpec.describe 'The y copy key in Chromium', type: :request do
  it 'copies what the status bar names, never the breadcrumb path' do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium DOM regression' unless ENV['WOODS_MAP_BROWSER']

    result = copy_key_result
    expect(result.fetch('cases')).to eq(8)
    expect(result.fetch('failures')).to eq([])
  end

  def copy_key_result
    Dir.mktmpdir('woods-map-copy-key') do |directory|
      fixture = File.join(directory, 'copy_key.html')
      File.write(fixture, copy_key_fixture)
      output, error, status = Open3.capture3(
        ENV.fetch('WOODS_MAP_BROWSER'), '--headless', '--disable-gpu', '--disable-background-networking',
        '--no-first-run', '--virtual-time-budget=30000', "--user-data-dir=#{File.join(directory, 'profile')}",
        '--dump-dom', "file://#{fixture}"
      )
      result = Nokogiri::HTML(output).at_css('#result')
      unless status.success? && result && !result.text.empty?
        raise "Copy key regression did not produce results: #{error}"
      end

      JSON.parse(result.text)
    end
  end

  def copy_key_pages
    { '/woods/units/model/User/schema' => '⎘ copy Mermaid', '/woods/units/model/User/lifecycle' => '⎘ copy Mermaid',
      '/woods/units/controller/UsersController/passage?action_name=edit' => '⎘ copy as Mermaid',
      '/woods/impact?focus=User' => '⎘ copy focus URL' }.map do |path, expected|
      get path
      { path: path, expected: expected, html: response.parsed_body.at_css('main').inner_html }
    end
  end

  def copy_key_fixture
    root = File.expand_path('..', __dir__)
    keys = File.read(File.join(root, 'app/javascript/woods_map/controllers/keys_controller.js'))
    data = JSON.generate(pages: copy_key_pages, keys: keys).gsub('</', '<\\/')
    runner = File.read(File.join(root, 'spec/javascript/copy_key_runner.js'))
    '<!doctype html><html lang="en"><body><pre id="result"></pre>' \
      "<script>const fixtureData = #{data};\n#{runner}</script></body></html>"
  end
end
