# frozen_string_literal: true

RSpec.describe WoodsMap::CodeView do
  let(:repository) { instance_double(WoodsMap::Repository) }
  let(:unit) do
    { 'identifier' => 'Caller', 'file_path' => 'app/caller.rb', 'source_code' => source,
      'metadata' => { 'references' => records } }
  end
  let(:source) { "class Caller\n  Target.call; Target.call\nend\n" }
  let(:record) do
    { 'line' => 2, 'column' => 15, 'length' => 6, 'target' => 'Space::Target',
      'target_type' => 'service', 'kind' => 'constant', 'confidence' => 'verified' }
  end
  let(:records) { [record] }

  before do
    allow(repository).to receive(:unit).with('Space::Target', type: 'service')
                                       .and_return('identifier' => 'Space::Target', 'type' => 'service')
  end

  def rows(lens = 'written')
    described_class.new(unit, lens: lens, references: WoodsMap::References.new(repository, unit),
                              marginalia: instance_double(WoodsMap::Marginalia, for_line: nil),
                              unit_path: ->(identifier, type) { "/mount/units/#{type}/#{identifier}" }).rows
  end

  def fragment(row)
    Nokogiri::HTML5.fragment(row.html)
  end

  it 'links the second occurrence without changing source text, gutter labels or row numbers' do
    rendered = rows
    expect(fragment(rendered[1]).css('a').map(&:text)).to eq(['Target'])
    expect(fragment(rendered[1]).at_css('a').xpath('preceding-sibling::node()').map(&:text).join)
      .to eq('  Target.call; ')
    expect(rendered.map { |row| fragment(row).text }).to eq(source.lines(chomp: true))
    expect(rendered.map { |row| [row.number, row.label] }).to eq([[1, '1'], [2, '2'], [3, '3']])
  end

  it 'wraps a rooted qualified name spanning syntax tokens in one anchor' do
    unit['source_code'] = "::Space::Target.call\n"
    record.merge!('line' => 1, 'column' => 0, 'length' => 15)
    link = fragment(rows.first).at_css('a')
    expect(link.text).to eq('::Space::Target')
    expect(link['href']).to eq('/mount/units/service/Space::Target')
    expect(link.css('span').size).to be > 1
  end

  it 'projects annotated numbers independently of original gutter labels in both lenses' do
    unit['source_code'] = "# Target header\n#{source}"
    unit['metadata']['source_line_map'] = [[2, 20, 3]]
    record['line'] = 3
    %w[written effective].each do |lens|
      rendered = rows(lens).select { |row| row.kind == :line }
      expect(rendered.map(&:label)).to eq(%w[20 21 22])
      expect(rendered.map { |row| fragment(row).css('a').size }).to eq([0, 1, 0])
    end
  end

  it 'leaves hidden headers and transformed concern text unlinked' do
    unit['source_code'] = "# Target header\nclass Caller\n# │ Included from: Concern\n#   Target\n" \
                          "# ─── End Concern ───\n  Target\nend\n"
    unit['metadata']['source_line_map'] = [[2, 1, 1], [6, 2, 2]]
    records.replace([1, 4, 6].map { |line| record.merge('line' => line, 'column' => line == 4 ? 4 : 2) })
    rendered = rows('effective')
    expect(rendered.select(&:concern).map { |row| fragment(row).css('a').size }).to eq([0, 0])
    expect(rendered.select { |row| row.kind == :line && !row.concern }.map(&:label)).to eq(%w[1 2 3])
    expect(rendered.sum { |row| fragment(row).css('a').size }).to eq(1)
  end

  ["\n", "\r\n"].each do |newline|
    it "preserves Unicode, tabs and multiline #{newline.inspect} byte intervals in both lenses" do
      unit['source_code'] = "'雪';\tSpace::#{newline}\tTarget.call#{newline}"
      record.merge!('line' => 1, 'column' => 7, 'length' => 14 + newline.bytesize)
      %w[written effective].each do |lens|
        rendered = rows(lens)
        expect(rendered.map { |row| fragment(row).text }).to eq(unit['source_code'].split("\n")[0..1])
        expect(rendered.map { |row| fragment(row).css('a').size }).to eq([1, 1])
      end
    end
  end

  it 'rejects a whole span crossing hidden content even when its endpoints are file rows' do
    unit['source_code'] = "Space::\n# inserted\nTarget\n"
    unit['metadata']['source_line_map'] = [[1, 1, 1], [3, 2, 1]]
    record.merge!('line' => 1, 'column' => 0, 'length' => unit['source_code'].bytesize - 1)
    expect(rows.map { |row| fragment(row).css('a').size }).to eq([0, 0])
  end

  it 'preserves empty final rows instead of handing a missing HTML value to the view' do
    unit['source_code'] = "Target\n\n"
    records.clear
    expect(rows.map(&:html)).to all(be_a(String))
    expect(rows.map { |row| fragment(row).text }).to eq(['Target', ''])
  end
end
