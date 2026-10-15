# frozen_string_literal: true

RSpec.describe WoodsMap::Importmap do
  it 'resolves pinned logical paths inside the engine roots' do
    expect(described_class.resolve('woods_map/application.js')).to be_file
  end

  it 'refuses paths that escape the roots' do
    expect(described_class.resolve('../../lib/woods_map.rb')).to be_nil
    expect(described_class.resolve('/etc/passwd')).to be_nil
  end

  it 'emits an import map whose URLs carry the content digest' do
    json = JSON.parse(described_class.to_json(url_for: ->(digest, path) { "/woods/assets/#{digest}/#{path}" }))
    digest = described_class.digest('woods_map/application.js')
    expect(json['imports']['woods_map']).to eq("/woods/assets/#{digest}/woods_map/application.js")
  end
end
