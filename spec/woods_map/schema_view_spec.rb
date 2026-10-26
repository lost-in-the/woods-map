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
                            { 'name' => 'f', 'default' => '  ' },
                            { 'name' => 'g', 'default' => "\t" },
                            { 'name' => 'd', 'has_default' => false },
                            { 'name' => 'e' }])
      expect(result).to eq('a' => 'false', 'b' => '0', 'c' => '""', 'd' => 'none', 'e' => nil,
                           'f' => '"  "', 'g' => '"\\t"')
    end
  end

  describe 'incoming foreign keys' do
    let(:user) do
      { 'identifier' => 'User', 'type' => 'model', 'metadata' => { 'table_name' => 'users', 'associations' => [
        { 'type' => 'has_many', 'name' => 'posts', 'target' => 'Post', 'foreign_key' => 'user_id' },
        { 'type' => 'has_one', 'name' => 'profile', 'target' => 'Profile', 'foreign_key' => 'user_id' },
        { 'type' => 'has_many', 'name' => 'notes', 'target' => 'Note', 'foreign_key' => 'owner_id' },
        { 'type' => 'has_many', 'name' => 'tags', 'target' => 'Tag', 'through' => 'taggings' },
        { 'type' => 'has_many', 'name' => 'comments', 'target' => 'Comment' }
      ] } }
    end
    let(:tables) do
      { 'posts' => { 'metadata' => { 'foreign_keys' => [{ 'column' => 'user_id', 'to_table' => 'users' }] } },
        'notes' => { 'metadata' => { 'foreign_keys' => [{ 'column' => 'owner_id', 'to_table' => 'people' }] } } }
    end
    let(:enforced) do
      view = described_class.new(user, tables: { 'Note' => 'notes' }, table_lookup: ->(name) { tables[name] })
      view.associations.to_h { |a| [a.name, a.enforced] }
    end

    it 'shows the far table foreign key that points at this table' do
      expect(enforced['posts']).to eq('✓ FK posts.user_id → users')
    end

    it 'is unchecked, with a reason, when the far table is not in the index' do
      expect(enforced['profile']).to eq('unchecked: table profiles not in the index')
    end

    it 'is unchecked when the far table publishes no foreign key to this table' do
      expect(enforced['notes']).to eq('unchecked: no foreign key to users published on notes')
    end

    it 'is unchecked when the association publishes no foreign key, and via join for through' do
      expect(enforced['comments']).to eq('unchecked: association publishes no foreign key')
      expect(enforced['tags']).to eq('via join')
    end

    it 'never prints a bare dash' do
      expect(enforced.values).not_to include('—')
    end
  end

  describe 'Rails dependent behaviour' do
    it 'is named as Rails behaviour, with the database delete action said to be unpublished' do
      unit = { 'identifier' => 'User', 'type' => 'model', 'metadata' => { 'table_name' => 'users', 'associations' => [
        { 'type' => 'has_many', 'name' => 'posts', 'target' => 'Post', 'foreign_key' => 'user_id',
          'options' => { 'dependent' => 'destroy' } }
      ] } }
      finding = described_class.new(unit).associations.first.finding
      expect(finding).to eq('delete radius: Rails dependent destroy; database delete action not published')
    end
  end
end
