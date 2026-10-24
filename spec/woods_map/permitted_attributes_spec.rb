# frozen_string_literal: true

require_relative '../support/action_facts_fixture'

RSpec.describe WoodsMap::PermittedAttributes do
  include ActionFactsFixture

  def fixture_attributes(model, keys)
    WoodsMap::Repository.open(FIXTURE_INDEX) do |repository|
      entry = { 'method' => "#{model}_params", 'model' => model, 'permitted' => keys }
      described_class.new(repository, entry).tap(&:keys)
    end
  end

  def synthetic_model(metadata)
    { 'identifier' => 'Widget', 'type' => 'model', 'file_path' => 'app/models/widget.rb', 'metadata' => metadata,
      'dependencies' => [] }
  end

  it 'matches permitted keys to published columns and attachments' do
    attributes = fixture_attributes('micropost', %w[content image])
    expect(attributes.model['identifier']).to eq('Micropost')
    expect(attributes.matched_by_fact).to eq('column' => ['content'], 'attachment' => ['image'])
    expect(attributes.unverified).to eq([])
  end

  it 'leaves a key no published fact matches unverified, never claiming the model lacks it' do
    attributes = fixture_attributes('user', %w[name email password password_confirmation])
    expect(attributes.matched_by_fact).to eq('column' => %w[name email])
    expect(attributes.unverified.map(&:name)).to eq(%w[password password_confirmation])
  end

  it 'matches associations, collection ids, rich text and class-body writers' do
    model = synthetic_model(
      'column_names' => ['id'], 'instance_methods' => ['nickname='], 'action_text_fields' => ['notes'],
      'associations' => [{ 'name' => 'tags', 'type' => 'has_many' }, { 'name' => 'owner', 'type' => 'belongs_to' }]
    )
    repository = action_repository([model])
    keys = %w[tag_ids owner notes nickname nickname_attributes]
    entry = { 'method' => 'widget_params', 'model' => 'widget', 'permitted' => keys }
    attributes = described_class.new(repository, entry)
    expect(attributes.keys.map { |key| [key.name, key.via] })
      .to eq([['tag_ids', 'association ids'], %w[owner association], ['notes', 'rich text'], %w[nickname writer],
              ['nickname_attributes', nil]])
  end

  it 'checks nothing when the index holds no model the require key names' do
    entry = { 'method' => 'x_params', 'model' => 'profile', 'permitted' => ['bio'] }
    attributes = described_class.new(action_repository([]), entry)
    expect([attributes.model_name, attributes.model]).to eq(['Profile', nil])
    expect(attributes.keys.map(&:via)).to eq([nil])
  end
end
