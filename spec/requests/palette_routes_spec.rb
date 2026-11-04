# frozen_string_literal: true

require 'tmpdir'
require 'digest'

RSpec.describe 'Palette route identities', type: :request do
  let(:dir) { Dir.mktmpdir('woods-map-route-types') }

  before do
    FileUtils.cp_r(File.join(FIXTURE_INDEX, '.'), dir)
    routes = File.join(dir, 'payloads/gen-1/routes')
    identifier = 'config/paletteprobe.rb'
    unit = { 'identifier' => identifier, 'type' => 'route_file', 'file_path' => identifier,
             'source_code' => "Rails.application.routes.draw do\nend\n", 'metadata' => {} }
    filename = "config_paletteprobe_rb_#{Digest::SHA256.hexdigest(identifier)[0, 8]}.json"
    File.write(File.join(routes, filename), JSON.generate(unit))
    index_path = File.join(routes, '_index.json')
    entries = JSON.parse(File.read(index_path))
    File.write(index_path, JSON.generate(entries + [unit.slice('identifier', 'type', 'file_path')]))
    route = JSON.parse(File.read(File.join(routes, 'GET__users_ca0e1629.json')))
    route['identifier'] = 'GET /paletteprobe'
    route_name = "GET__paletteprobe_#{Digest::SHA256.hexdigest(route['identifier'])[0, 8]}.json"
    File.write(File.join(routes, route_name), JSON.generate(route))
    entries = JSON.parse(File.read(index_path))
    File.write(index_path, JSON.generate(entries + [route.slice('identifier', 'type', 'file_path')]))
    manifest_path = File.join(dir, 'payloads/gen-1/manifest.json')
    manifest = JSON.parse(File.read(manifest_path))
    manifest['counts']['routes'] += 2
    manifest['total_units'] += 2
    File.write(manifest_path, JSON.generate(manifest))
    WoodsMap.configuration.index_dir = dir
  end

  after { FileUtils.remove_entry(dir) }

  it 'lists route files exactly once with their real type and a working link' do
    get '/woods/search/palette', params: { q: 'paletteprobe' }
    groups = response.parsed_body['groups'].index_by { |group| group['name'] }
    expect(groups.fetch('routes')['items']).to all(include('type' => 'route'))
    files = groups.values.flat_map { |group| group['items'] }.select do |item|
      item['identifier'] == 'config/paletteprobe.rb'
    end
    expect(files.size).to eq(1)
    expect(groups.fetch('units')['items']).to include(include('type' => 'route_file',
                                                              'identifier' => 'config/paletteprobe.rb'))
    get files.first.fetch('href')
    expect(response).to have_http_status(:ok)
  end
end
