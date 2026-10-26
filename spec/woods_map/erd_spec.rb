# frozen_string_literal: true

require_relative '../support/large_schema_index'

RSpec.describe WoodsMap::Erd do
  def erd_of(dir)
    WoodsMap::Repository.open(dir) { |repository| described_class.build(repository) }
  end

  it 'reads a generation once and serves it from the cache' do
    described_class.reset!
    first = WoodsMap::Repository.open(FIXTURE_INDEX) { |repository| described_class.for(repository) }
    expect(WoodsMap::Repository.open(FIXTURE_INDEX) { |repository| described_class.for(repository) }).to be(first)
  end

  describe 'on the fixture index' do
    let(:erd) { erd_of(FIXTURE_INDEX) }
    let(:chunk) { erd.chunks('namespace').first }

    it 'puts every table in one chunk and relates them by foreign keys and associations' do
      expect(erd.chunks('namespace').map(&:tables)).to eq([%w[microposts users relationships]])
      expect(erd.relations.map { |r| [r.from, r.column, r.to, r.enforced, r.association] })
        .to eq([['microposts', 'user_id', 'users', true, true],
                ['relationships', 'followed_id', 'users', false, true],
                ['relationships', 'follower_id', 'users', false, true]])
    end

    it 'draws the chunk with key columns, dotting a relation no foreign key enforces' do
      text = erd.mermaid(chunk)
      expect(text).to start_with("erDiagram\n  \"microposts\" {\n    integer id PK\n    integer user_id FK\n  }")
      expect(text).to include('    string email UK', '    integer follower_id "no FK"',
                              '"microposts" }o--|| "users" : "user_id"',
                              '"relationships" }o..|| "users" : "followed_id"')
      expect(text).not_to include('created_at')
      expect(erd.mermaid(chunk, columns: 'all')).to include('    datetime created_at')
    end

    it 'draws a noted column even in the keys-only view and joins notes with a key comment (?since=)' do
      notes = { 'microposts' => { 'content' => 'modified since gen 1' },
                'relationships' => { 'follower_id' => 'added since gen 1' } }
      text = erd.mermaid(chunk, notes: notes)
      expect(text).to include('    text content "modified since gen 1"',
                              '    integer follower_id "no FK, added since gen 1"')
      expect(erd.mermaid(chunk)).not_to include('content')
    end

    it 'finds associations without a foreign key, from the published facts only' do
      expect(erd.findings.map { |f| [f.severity, f.rule, f.where.last] })
        .to eq([[:blocking, 'association without a foreign key, not polymorphic', 'relationships.followed_id'],
                [:blocking, 'association without a foreign key, not polymorphic', 'relationships.follower_id']])
      expect(erd.findings.for_table(erd.table_named('relationships')).size).to eq(2)
      expect(erd.findings.for_table(erd.table_named('users'))).to be_empty
    end
  end

  describe 'on a 300-model index' do
    let(:erd) { erd_of(WoodsMap::LargeSchemaIndex.path) }

    it 'cuts every grouping into chunks within the ER table budget, each table in exactly one' do
      expect(erd.tables.size).to eq(302)
      described_class::GROUPINGS.each do |by|
        chunks = erd.chunks(by)
        expect(chunks.map(&:tables).flatten).to match_array(erd.tables.map(&:name))
        expect(chunks.map { |c| c.tables.size }.max).to be <= WoodsMap::SchemaView::TABLE_BUDGET
        expect(chunks.map(&:number)).to eq((1..chunks.size).to_a)
      end
    end

    it 'chunks by namespace within each database, a large namespace in parts that keep a chain together' do
      chunks = erd.chunks('namespace')
      expect(chunks.map(&:label).first(2)).to eq(['Accounts 1 of 2', 'Accounts 2 of 2'])
      expect(chunks.last(2).map(&:database)).to eq(%w[analytics analytics])
      expect(chunks.find { |c| c.group == '(no namespace)' }.tables).to eq(%w[legacy_imports schema_audits])
      expect(erd.inner_relations(chunks.first).size).to eq(39)
    end

    it 'lists the relations that leave a chunk with the chunk at the other end' do
      blog = erd.chunks('namespace').find { |c| c.label == 'Blog 1 of 2' }
      crossing = erd.crossing_relations(blog, 'namespace').map { |r, other| [r.from, r.column, r.to, other.label] }
      expect(crossing).to include(['blog_model1s', 'owner_id', 'accounts_model1s', 'Accounts 1 of 2'])
    end

    it 'draws no relation whose other end is outside the chunk' do
      erd.chunks('database').each do |chunk|
        drawn = erd.mermaid(chunk).scan(/^  "([^"]+)" \S+ "([^"]+)"/).flatten.uniq
        expect(drawn - chunk.tables).to be_empty
      end
    end

    it 'finds every kind of schema finding the published facts support' do
      rules = erd.findings.group_by(&:rule).transform_values(&:size)
      expect(rules).to eq('association without a foreign key, not polymorphic' => 96,
                          'foreign key without an association' => 1,
                          'cross-database association, no FK, no join' => 1,
                          'unmodelled table' => 2,
                          'polymorphic columns without FK, by design' => 1)
      expect(erd.findings.cross_database_pairs).to eq(['analytics ↔ primary'])
    end
  end

  describe 'unmodelled tables named by the graph analysis' do
    def table_unit(name, model: nil)
      { 'identifier' => "table:#{name}", 'type' => 'database_table',
        'metadata' => { 'table_name' => name, 'database' => 'primary', 'model' => model, 'model_less' => model.nil?,
                        'columns' => [], 'indexes' => [], 'foreign_keys' => [] } }
    end

    let(:tables) { [table_unit('gen_hubs'), table_unit('gen_records'), table_unit('users', model: 'User')] }
    let(:models) { [{ 'identifier' => 'User', 'type' => 'model', 'metadata' => { 'table_name' => 'users' } }] }

    it 'counts a table once whether the analysis names it typed, bare or both' do
      erd = described_class.new(tables: tables, models: models,
                                unmodelled: %w[table:gen_hubs table:gen_records gen_hubs])
      expect(erd.unmodelled).to eq(%w[gen_hubs gen_records])
      expect(erd.findings.counts.values_at(:tables, :modelled, :unmodelled)).to eq([3, 1, 2])
      unmodelled = erd.findings.select { |f| f.rule == 'unmodelled table' }
      expect(unmodelled.map(&:where)).to eq([['gen_hubs'], ['gen_records']])
    end

    it 'keeps a name the index does not publish out of the physical count, and names it apart' do
      erd = described_class.new(tables: tables, models: models, unmodelled: %w[table:gen_hubs table:ghost])
      expect(erd.unmodelled).to eq(%w[gen_hubs gen_records])
      expect(erd.unresolved_unmodelled).to eq(%w[ghost])
      expect(erd.findings.counts[:unmodelled]).to eq(2)
      expect(erd.findings.map(&:rule)).to include('analysis names a table the index does not publish')
    end
  end
end
