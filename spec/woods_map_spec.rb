# frozen_string_literal: true

RSpec.describe WoodsMap do
  it 'loads under its Bundler name, woods-map' do
    expect(require('woods-map')).to be(false).or be(true)
    expect(described_class).to respond_to(:configure)
  end
end
