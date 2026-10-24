# frozen_string_literal: true

RSpec.describe WoodsMap::PublicUrl do
  it 'keeps an absolute http(s) URL, with a path prefix, less a trailing slash' do
    expect(described_class.normalize('https://staging.example.com/')).to eq('https://staging.example.com')
    expect(described_class.normalize(' http://example.com:8080/tools ')).to eq('http://example.com:8080/tools')
    expect([described_class.normalize(nil), described_class.normalize('  ')]).to eq([nil, nil])
  end

  it 'refuses what is not an absolute http(s) URL, or carries credentials, a query or a fragment' do
    ['staging.example.com', '/woods', 'ftp://example.com', 'https://user:pass@example.com',
     'https://example.com/?a=1', 'https://example.com/#x', 'https://exa mple.com'].each do |value|
      expect { described_class.normalize(value) }.to raise_error(ArgumentError, /config\.public_url/), value
    end
  end

  it 'is the configuration\'s public_url, defaulting to WOODS_MAP_PUBLIC_URL' do
    config = WoodsMap::Configuration.new
    config.public_url = 'https://map.example.com/'
    expect(config.public_url).to eq('https://map.example.com')
    expect { config.public_url = 'nope' }.to raise_error(ArgumentError)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('WOODS_MAP_PUBLIC_URL', nil).and_return('https://env.example.com')
    expect(WoodsMap::Configuration.new.public_url).to eq('https://env.example.com')
  end

  it 'starts a link at the configured URL, else at the request\'s origin' do
    request = instance_double(ActionDispatch::Request, base_url: 'http://10.0.0.5:3000')
    expect(described_class.base(request, nil)).to eq('http://10.0.0.5:3000')
    expect(described_class.base(request, 'https://map.example.com')).to eq('https://map.example.com')
  end
end
