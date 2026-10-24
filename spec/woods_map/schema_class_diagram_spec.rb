# frozen_string_literal: true

RSpec.describe WoodsMap::SchemaClassDiagram do
  let(:unit) do
    { 'identifier' => 'Post', 'type' => 'model',
      'metadata' => { 'parent_class' => 'ApplicationRecord', 'inlined_concerns' => ['Taggable'],
                      'columns' => [{ 'name' => 'id', 'type' => 'integer' },
                                    { 'name' => 'created_at', 'type' => 'datetime(6)' }],
                      'scopes' => [{ 'name' => 'published' }], 'instance_methods' => ['publish!', 'to_param'],
                      'associations' => [
                        { 'type' => 'belongs_to', 'name' => 'author', 'target' => 'User' },
                        { 'type' => 'has_many', 'name' => 'attachments', 'target' => 'ActiveStorage::Attachment' },
                        { 'type' => 'has_many', 'name' => 'tags', 'target' => 'Tag', 'through' => 'taggings' }
                      ] } }
  end

  it 'draws the model with its columns, scopes and own methods, its parent, concerns and one hop' do
    text = described_class.new(unit).mermaid
    expect(text).to start_with("classDiagram\n  class Post {\n    +integer id\n    +datetime created_at\n    " \
                               "+published()$\n")
    expect(text).to include('ApplicationRecord <|-- Post', 'Post ..|> Taggable : include',
                            'Post --> "1" User : belongs_to author',
                            'class ActiveStorage__Attachment["ActiveStorage::Attachment"]',
                            'Post --> "*" ActiveStorage__Attachment : has_many attachments')
    expect(text).not_to include('Tag :')
  end

  it 'counts the classes against the budget and caps long member lists' do
    diagram = described_class.new(unit)
    expect([diagram.class_count, diagram.refusal]).to eq([5, nil])
    unit['metadata']['instance_methods'] = (1..20).map { |i| "m#{i}" }
    expect(described_class.new(unit).mermaid).to include('+6 more methods')
    stub_const('WoodsMap::SchemaClassDiagram::CLASS_BUDGET', 2)
    expect(described_class.new(unit).refusal).to include('over the class diagram budget of 2')
  end
end
