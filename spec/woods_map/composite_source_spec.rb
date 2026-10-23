# frozen_string_literal: true

RSpec.describe WoodsMap::CompositeSource do
  let(:unit) do
    {
      'identifier' => 'Post',
      'source_code' => <<~SRC,
        # == Schema Information
        #
        # Table: posts
        #
        # Columns:
        #   id                        integer         NOT NULL PRIMARY KEY
        #   title                     string

        class Post < ApplicationRecord
        # ┌─────────────────────────────────────────────────────────────────────┐
        # │ Included from: Taggable                                              │
        # └─────────────────────────────────────────────────────────────────────┘
        #   has_many :tags
        #   def tag_list = tags.map(&:name)
        # ─────────────────────────── End Taggable ───────────────────────────
          include Taggable
          has_many :comments
        end
      SRC
      'metadata' => { 'source_line_map' => [[9, 1, 1], [16, 2, 3]] }
    }
  end
  let(:source) { described_class.new(unit) }

  it 'gives the file lines their own numbers and leaves the header and the concern out' do
    expect(source.file_lines.map(&:label)).to eq(%w[1 2 3 4])
    expect(source.file_lines.map(&:text)).to eq(['class Post < ApplicationRecord', '  include Taggable',
                                                 '  has_many :comments', 'end'])
  end

  it 'reads the schema header without its comment marks' do
    expect(source.header).to include('Table: posts').and include('  title                     string')
  end

  it 'de-comments each inlined concern and labels its lines c:N' do
    expect(source.concerns.keys).to eq(['Taggable'])
    expect(source.concerns['Taggable'].map(&:text)).to eq(['has_many :tags', 'def tag_list = tags.map(&:name)'])
    expect(source.concerns['Taggable'].map(&:label)).to eq(%w[c:1 c:2])
  end

  it 'finds the definition line and maps file lines back to the composite' do
    expect(source.definition_line).to eq(1)
    expect(source.composite_line_for(3)).to eq(17)
    expect(source.composite_line_for(99)).to be_nil
  end

  it 'treats a unit without a line map as all file' do
    plain = described_class.new('source_code' => "a\nb\n", 'metadata' => {})
    expect(plain.file_lines.map(&:label)).to eq(%w[1 2])
  end

  it 'interprets each published run as annotated start, original start and length' do
    mapped = described_class.new('source_code' => "# header\na\nb\n# hidden\nc\n",
                                 'metadata' => { 'source_line_map' => [[2, 20, 2], [5, 22, 1]] })
    expect(mapped.file_lines.map { |line| [line.number, line.label] }).to eq([[2, '20'], [3, '21'], [5, '22']])
    expect(mapped.composite_line_for(21)).to eq(3)
    expect(mapped.composite_line_for(23)).to be_nil
  end
end
