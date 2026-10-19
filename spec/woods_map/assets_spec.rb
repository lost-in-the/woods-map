# frozen_string_literal: true

RSpec.describe WoodsMap::Assets do
  it 'resolves the sheets, the modules and the fonts under their roots' do
    sheets = [described_class::TOKENS, described_class::MAP, described_class::FONTS]
    expect(sheets.map { |sheet| described_class.resolve(sheet) }).to all(be_file)
    expect(described_class.resolve('stimulus.js')).to be_file
    expect(described_class.resolve('fira-code/FiraCode-Regular.woff2')).to be_file
  end

  it 'refuses paths that escape the roots, absolute paths, NUL bytes and unserved extensions' do
    expect(described_class.resolve('../../lib/woods_map.rb')).to be_nil
    expect(described_class.resolve('/etc/passwd')).to be_nil
    expect(described_class.resolve("woods_map/tokens.css\0")).to be_nil
    expect(described_class.resolve('fira-code/LICENSE')).to be_nil
  end

  it 'digests the whole set once, as 16 hex characters' do
    first = described_class.digest
    expect(first).to match(/\A\h{16}\z/)
    expect(described_class.digest).to equal(first)
  end

  it 'lists every served file by logical path' do
    expect(described_class.files.keys).to include('woods_map/application.js', 'woods_map/tokens.css', 'stimulus.js')
    expect(described_class.files.keys).not_to include('README.md')
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

  describe 'the fonts' do
    it 'declares Inter and Fira Code at 400, 500 and 700 from the vendored files only (D-12)' do
      css = described_class.resolve(described_class::FONTS).read
      expect(css.scan(/font-family:"(Inter|Fira Code)";font-style:normal;font-weight:(\d+)/).uniq.size).to eq(6)
      expect(css).not_to include('http')
      css.scan(%r{url\(\.\./([^)]+)\)}).flatten.each { |font| expect(described_class.resolve(font)).to be_file }
    end
  end
end
