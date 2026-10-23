# frozen_string_literal: true

RSpec.describe WoodsMap::References do
  let(:repository) { instance_double(WoodsMap::Repository) }
  let(:record) do
    { 'line' => 1, 'column' => 13, 'length' => 6, 'target' => 'Space::Target',
      'target_type' => 'service', 'kind' => 'constant', 'confidence' => 'verified' }
  end
  let(:unit) { { 'source_code' => "Target.call; Target.call\n", 'metadata' => { 'references' => [record] } } }
  let(:lines) { WoodsMap::CompositeSource.new(unit).file_lines }
  let(:references) { described_class.new(repository, unit) }

  before do
    allow(repository).to receive(:unit).with('Space::Target', type: 'service')
                                       .and_return('identifier' => 'Space::Target', 'type' => 'service')
  end

  def projected
    references.by_source_line(lines)
  end

  it 'keeps only the published occurrence and the exact typed identity' do
    link = projected.fetch(1).sole
    expect([link.column, link.length, link.identifier, link.type, link.kind, link.confidence])
      .to eq([13, 6, 'Space::Target', 'service', 'constant', 'verified'])
    expect(repository).to have_received(:unit).with('Space::Target', type: 'service').once
  end

  [nil, {}, 'references', false, [], [nil, 1, 'Target', {}]].each do |value|
    it "leaves unavailable or malformed references unlinked: #{value.inspect}" do
      unit['metadata']['references'] = value
      expect(projected).to be_empty
      expect(repository).not_to have_received(:unit)
    end
  end

  it 'accepts legacy missing metadata' do
    unit.delete('metadata')
    expect(projected).to be_empty
  end

  { 'line' => [0, -1, 2, 1.0, '1', nil, true, 10**100], 'column' => [-1, 24, 1.5, '13', nil, 10**100],
    'length' => [0, -1, 1000, 6.0, '6', nil], 'kind' => ['method', nil],
    'confidence' => ['static', 'runtime', nil], 'target' => ['', [], nil],
    'target_type' => ['', {}, nil] }.each do |key, values|
    values.each do |value|
      it "rejects #{key}=#{value.inspect}" do
        record[key] = value
        expect(projected).to be_empty
      end
    end
  end

  it 'requires the requested typed unit even when another type owns the name' do
    allow(repository).to receive(:unit).with('Space::Target', type: 'service').and_return(nil)
    expect(projected).to be_empty
  end

  it 'leaves a target rejected by the published reader guards unlinked' do
    allow(repository).to receive(:unit).with('Space::Target', type: 'service').and_raise(IOError)
    expect(projected).to be_empty
  end

  it 'rejects a typed reader returning a mismatched identity' do
    allow(repository).to receive(:unit).with('Space::Target', type: 'service')
                                       .and_return('identifier' => 'Space::Target', 'type' => 'model')
    expect(projected).to be_empty
  end

  it 'collapses identical duplicates while preserving repeated and adjacent intervals in source order' do
    unit['source_code'] = 'TargetTarget Target'
    unit['metadata']['references'] = [13, 6, 0, 6].map { |column| record.merge('column' => column) }
    expect(projected.fetch(1).map(&:column)).to eq([0, 6, 13])
    expect(repository).to have_received(:unit).once
  end

  it 'rejects every interval in a conflicting overlap group, retaining a later disjoint occurrence' do
    unit['source_code'] = 'TargetTarget Target'
    unit['metadata']['references'] = [0, 3, 6, 13].map { |column| record.merge('column' => column) }
    expect(projected.fetch(1).map(&:column)).to eq([13])
  end

  it 'rejects different targets claiming the same interval' do
    unit['metadata']['references'] << record.merge('target' => 'Other')
    expect(projected).to be_empty
    expect(repository).not_to have_received(:unit)
  end

  it 'uses byte coordinates after Unicode and tabs' do
    unit['source_code'] = "'雪';\tTarget\r\n"
    record['column'] = 7
    expect(projected.fetch(1).sole.column).to eq(7)
  end

  it 'rejects partial UTF-8 characters at either boundary' do
    unit['source_code'] = '雪Target'
    [record.merge('column' => 1), record.merge('column' => 0, 'length' => 2)].each do |invalid|
      unit['metadata']['references'] = [invalid]
      expect(projected).to be_empty
    end
  end

  ["\n", "\r\n"].each do |newline|
    it "splits a consecutive multiline span using original #{newline.inspect} bytes" do
      unit['source_code'] = "\tSpace::#{newline}\tTarget.call#{newline}"
      record.merge!('column' => 1, 'length' => 14 + newline.bytesize)
      expect(projected.transform_values { |links| links.map { |link| [link.column, link.length] } })
        .to eq(1 => [[1, 7 + newline.bytesize - 1]], 2 => [[0, 7]])
    end
  end

  it 'rejects a multiline span crossing hidden annotation rows as a whole' do
    unit['source_code'] = "Space::\n# annotation\nTarget\n"
    unit['metadata']['source_line_map'] = [[1, 1, 1], [3, 2, 1]]
    record.merge!('column' => 0, 'length' => 27)
    expect(projected).to be_empty
  end

  it 'rejects a transformed row even if it is incorrectly offered as a file row' do
    lines.first.text = 'different'
    expect(projected).to be_empty
  end
end
