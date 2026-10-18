# frozen_string_literal: true

RSpec.describe WoodsMap::Assets do
  it 'resolves the token sheet and the engine sheet under the stylesheet root' do
    expect(described_class.resolve(described_class::TOKENS)).to be_file
    expect(described_class.resolve(described_class::MAP)).to be_file
  end

  it 'refuses paths that escape the roots, absolute paths and NUL bytes' do
    expect(described_class.resolve('../../lib/woods_map.rb')).to be_nil
    expect(described_class.resolve('/etc/passwd')).to be_nil
    expect(described_class.resolve("woods_map/tokens.css\0")).to be_nil
  end

  it 'digests a file by content and answers nil for an unknown path' do
    expect(described_class.digest(described_class::TOKENS)).to match(/\A\h{16}\z/)
    expect(described_class.digest('woods_map/missing.css')).to be_nil
  end

  it 'types stylesheets, scripts and fonts' do
    expect(described_class.content_type(Pathname.new('a/tokens.css'))).to start_with('text/css')
    expect(described_class.content_type(Pathname.new('a/application.js'))).to start_with('text/javascript')
    expect(described_class.content_type(Pathname.new('a/inter-400.woff2'))).to eq('font/woff2')
  end

  describe 'the token sheet' do
    let(:engine_copy) { described_class.resolve(described_class::TOKENS) }
    let(:design_copy) { Pathname.new(File.expand_path('../../docs/design/foundations/tokens.css', __dir__)) }

    it 'is the design foundations file, byte for byte (D-10)' do
      expect(engine_copy.read).to eq(design_copy.read)
    end

    it 'declares the container every width tier queries (D-19)' do
      expect(engine_copy.read).to include('container-name:wm')
    end
  end
end
