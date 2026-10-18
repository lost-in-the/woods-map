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

  describe '#boot_warning' do
    it 'warns that only loopback is served while no token is configured' do
      config = described_class.new
      config.token = nil
      expect(config.boot_warning).to include('loopback requests only').and include('WOODS_MAP_TOKEN')
    end

    it 'warns that every request is refused when require_token is set without a token' do
      config = described_class.new
      config.token = nil
      config.require_token = true
      expect(config.boot_warning).to include('refuses every request')
    end

    it 'is silent once a token is configured' do
      config = described_class.new
      config.token = 'secret'
      expect(config.boot_warning).to be_nil
    end
  end
end
