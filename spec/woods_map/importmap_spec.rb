# frozen_string_literal: true

RSpec.describe WoodsMap::Importmap do
  it 'pins the engine module and Stimulus under the set digest' do
    json = JSON.parse(described_class.to_json(url_for: ->(digest, path) { "/woods/assets/#{digest}/#{path}" }))
    digest = WoodsMap::Assets.digest
    expect(json['imports']['woods_map']).to eq("/woods/assets/#{digest}/woods_map/application.js")
    expect(json['imports']['@hotwired/stimulus']).to eq("/woods/assets/#{digest}/stimulus.js")
  end

  it 'pins the vendored Pele build the diagram panels load on demand (D-21)' do
    json = JSON.parse(described_class.to_json(url_for: ->(digest, path) { "/woods/assets/#{digest}/#{path}" }))
    expect(json['imports']['pele']).to eq("/woods/assets/#{WoodsMap::Assets.digest}/pele.js")
  end
end
