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

  it 'writes one ER line per direct association, a namespaced table as a valid entity name' do
    expect(described_class.new(unit).mermaid).to eq(<<~MERMAID.chomp)
      erDiagram
        microposts
        microposts }o--|| users : "user"
        microposts ||--o{ active_storage_attachments : "image_attachment"
    MERMAID
  end

  it 'declares the table on its own when the model has no associations' do
    unit['metadata']['associations'] = []
    expect(described_class.new(unit).mermaid).to eq("erDiagram\n  microposts")
  end
end
