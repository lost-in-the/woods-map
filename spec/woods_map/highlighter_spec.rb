# frozen_string_literal: true

RSpec.describe WoodsMap::Highlighter do
  let(:fragment_class) do
    Struct.new(:column, :length, :identifier, :type, :kind, :confidence, :method, :line, :popover, keyword_init: true)
  end
  let(:unit_path) { ->(identifier, type) { "/catalog/map/units/#{type}/#{identifier}" } }

  def reference(column, length, **attributes)
    fragment_class.new(column: column, length: length, identifier: 'Space::Target', type: 'service',
                       kind: 'constant', confidence: 'verified', **attributes)
  end

  def render(source, references, **options)
    described_class.lines(source, references: references, unit_path: unit_path, **options)
                   .map { |html| Nokogiri::HTML5.fragment(html) }
  end

  it 'highlights Ruby onto the code-view classes, one line each' do
    lines = described_class.lines("class Post < ApplicationRecord\n  # a comment\n  validates :title\nend\n")
    expect(lines.size).to eq(4)
    expect(lines[0]).to include('<span class="k">class</span>').and include('<span class="const">Post</span>')
    expect(lines[1]).to include('<span class="cm"># a comment</span>')
    expect(lines[2]).to include('<span class="str">:title</span>')
  end

  it 'escapes HTML and keeps unknown languages plain' do
    expect(described_class.lines('<b>', language: 'text')).to eq(['&lt;b&gt;'])
    expect(described_class.lines("x = '<b>'", language: 'ruby').first).to include('&lt;b&gt;')
  end

  it 'picks the lexer from the file extension' do
    expect(described_class.language_for('app/views/users/show.html.erb')).to eq('erb')
    expect(described_class.language_for('app/models/user.rb')).to eq('ruby')
  end

  it 'wraps a qualified constant across syntax tokens in one balanced link' do
    row = render('::Space::Target.call', { 1 => [reference(0, 15)] }).first
    anchor = row.at_css('a')
    expect(anchor.text).to eq('::Space::Target')
    expect(anchor.css('span').map(&:text).join).to eq('::Space::Target')
    expect(row.text).to eq('::Space::Target.call')
    expect(anchor['aria-label']).to eq('Space::Target (service), verified constant reference')
  end

  it 'links only the published repeated occurrence and keeps source-order attributes' do
    row = render('Target; Target', { 1 => [reference(8, 6, identifier: 'Target')] }).first
    anchor = row.at_css('a')
    expect(row.css('a').map(&:text)).to eq(['Target'])
    expect(anchor.xpath('preceding-sibling::node()').map(&:text).join).to eq('Target; ')
    expect(anchor.attributes.transform_values(&:value)).to include(
      'href' => '/catalog/map/units/service/Target', 'data-target' => 'Target',
      'data-type' => 'service', 'data-kind' => 'constant'
    )
  end

  it 'splits a syntax token at adjacent reference boundaries without nested anchors' do
    links = [reference(0, 2, identifier: 'AB'), reference(2, 2, identifier: 'CD')]
    row = render('ABCD', { 1 => links }).first
    expect(row.css('a').map(&:text)).to eq(%w[AB CD])
    expect(row.css('a a')).to be_empty
    expect(row.text).to eq('ABCD')
  end

  it 'preserves UTF-8 byte columns, tabs and CRLF while balancing each multiline fragment' do
    source = "'é';\tSpace::\r\n\tTarget.call\r\n"
    links = { 1 => [reference(6, 8)], 2 => [reference(0, 7)] }
    rows = render(source, links)
    expect(rows.map(&:text)).to eq(["'é';\tSpace::\r", "\tTarget.call\r"])
    expect(rows.map { |row| row.css('a').size }).to eq([1, 1])
    expect(rows.map { |row| row.at_css('a').text }).to eq(["Space::\r", "\tTarget"])
  end

  it 'preserves blank lines, LF and final non-newline rows' do
    rows = render("Target\n\nTarget", { 1 => [reference(0, 6)], 3 => [reference(0, 6)] })
    expect(rows.map(&:text)).to eq(['Target', '', 'Target'])
    expect(rows.map { |row| row.css('a').size }).to eq([1, 0, 1])
  end

  it 'escapes source and every attribute without interpreting target strings as URLs' do
    malicious = 'Target" onclick="alert(1)<&'
    allow(unit_path).to receive(:call).with(malicious, 'service').and_return('/safe?x="<&'.html_safe)
    row = render('<script>Target</script>', { 1 => [reference(8, 6, identifier: malicious)] }, language: 'text').first
    expect(row.css('script, [onclick]')).to be_empty
    expect(row.text).to eq('<script>Target</script>')
    expect(row.at_css('a')['href']).to eq('/safe?x="<&')
    expect(row.at_css('a')['data-target']).to eq(malicious)
  end

  it 'escapes malicious type and kind values as inert attributes' do
    malicious = 'service" onfocus="bad<&'
    ref = reference(0, 6, type: malicious, kind: malicious)
    row = render('Target', { 1 => [ref] }).first
    expect(row.css('[onfocus]')).to be_empty
    expect(row.at_css('a')['data-type']).to eq(malicious)
    expect(row.at_css('a')['data-kind']).to eq(malicious)
    expect(row.at_css('a')['aria-label']).to include(malicious)
  end

  it 'keeps unknown languages byte faithful and unlinked without a route closure' do
    html = described_class.lines("<é>\r\n", language: 'text', references: { 1 => [reference(0, 4)] }).first
    row = Nokogiri::HTML5.fragment(html)
    expect(row.text).to eq("<é>\r")
    expect(row.css('a')).to be_empty
  end

  it 'preserves source when a lexer does not return the exact input bytes' do
    source = "\tTarget\r\n"
    allow(Rouge::Lexers::Ruby).to receive(:lex).with(source).and_return([[Rouge::Token['Text'], 'Target']])
    row = render(source, { 1 => [reference(1, 6)] }).first
    expect(row.text).to eq("\tTarget\r")
    expect(row.at_css('a').text).to eq('Target')
  end
end
