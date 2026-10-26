# frozen_string_literal: true

RSpec.describe WoodsMap::SchemaView do
  let(:unit) do
    { 'identifier' => 'Micropost', 'type' => 'model',
      'metadata' => { 'table_name' => 'microposts', 'associations' => [
        { 'type' => 'belongs_to', 'name' => 'user', 'target' => 'User' },
        { 'type' => 'has_one', 'name' => 'image_attachment', 'target' => 'ActiveStorage::Attachment' },
        { 'type' => 'has_many', 'name' => 'tags', 'target' => 'Tag', 'through' => 'taggings' }
      ] } }
  end

  it 'writes one ER line per direct association, each table quoted as written' do
    expect(described_class.new(unit).mermaid).to eq(<<~MERMAID.chomp)
      erDiagram
        "microposts"
        "microposts" }o--|| "users" : "user"
        "microposts" ||--o{ "active_storage_attachments" : "image_attachment"
    MERMAID
  end

  it 'draws the far table a target model publishes, not one guessed from its name (M3 exit check)' do
    tables = { 'User' => 'accounts', 'ActiveStorage::Attachment' => 'active_storage_attachments' }
    text = described_class.new(unit, tables: tables).mermaid
    expect(text).to include('"microposts" }o--|| "accounts" : "user"')
    expect(text).to include('"microposts" ||--o{ "active_storage_attachments" : "image_attachment"')
  end

  it 'keeps a schema-qualified table apart from a table whose name differs only in punctuation' do
    unit['metadata'] = { 'table_name' => 'audit.logs',
                         'associations' => [{ 'type' => 'belongs_to', 'name' => 'archive', 'target' => 'AuditLog' }] }
    expect(described_class.new(unit).mermaid).to include('"audit.logs" }o--|| "audit_logs" : "archive"')
    expect(described_class.new(unit).table_count).to eq(2)
  end

  it 'declares the table on its own when the model has no associations' do
    unit['metadata']['associations'] = []
    expect(described_class.new(unit).mermaid).to eq("erDiagram\n  \"microposts\"")
  end

  it 'counts the tables against the ER budget, refusing only above it' do
    targets = ->(n) { (1..n).map { |i| { 'type' => 'has_many', 'name' => "t#{i}", 'target' => "Thing#{i}" } } }
    unit['metadata']['associations'] = targets.call(WoodsMap::SchemaView::TABLE_BUDGET - 1)
    expect(described_class.new(unit)).not_to be_over_budget
    unit['metadata']['associations'] = targets.call(WoodsMap::SchemaView::TABLE_BUDGET)
    expect(described_class.new(unit).table_count).to eq(WoodsMap::SchemaView::TABLE_BUDGET + 1)
    expect(described_class.new(unit)).to be_over_budget
  end

  describe 'column defaults' do
    def defaults_of(columns)
      view = described_class.new({ 'identifier' => 'T', 'type' => 'model', 'metadata' => { 'columns' => columns } })
      view.columns.to_h { |c| [c.name, c.default] }
    end

    it 'says a default exists and its value is not published when only presence is published' do
      result = defaults_of([{ 'name' => 'state', 'has_default' => true, 'default_digest' => 'abc123' }])
      expect(result['state']).to eq('exists, value not published')
    end

    it 'never reads a presence flag as a value, and keeps a published value as published' do
      result = defaults_of([{ 'name' => 'a', 'default' => false, 'has_default' => true },
                            { 'name' => 'b', 'default' => '0' },
                            { 'name' => 'c', 'default' => '' },
                            { 'name' => 'd', 'has_default' => false },
                            { 'name' => 'e' }])
      expect(result).to eq('a' => 'false', 'b' => '0', 'c' => '""', 'd' => 'none', 'e' => nil)
    end
  end
end
