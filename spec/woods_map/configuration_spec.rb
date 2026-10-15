# frozen_string_literal: true

RSpec.describe WoodsMap::Configuration do
  it 'defaults to a loopback-only, tokenless, guide-off mount under Rails.root/tmp/woods' do
    config = described_class.new
    expect(config.token?).to be(false)
    expect(config.require_token).to be(false)
    expect(config.guide_enabled).to be(false)
    expect(config.index_path.to_s).to end_with('tmp/woods')
  end

  it 'treats a blank token as absent' do
    config = described_class.new
    config.token = '   '
    expect(config.token?).to be(false)
  end
end
