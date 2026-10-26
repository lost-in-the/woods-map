# frozen_string_literal: true

RSpec.describe WoodsMap::Outline do
  def perform_item(params)
    unit = { 'identifier' => 'PublishArticleJob', 'type' => 'job',
             'metadata' => { 'perform_params' => params, 'queue' => 'default' } }
    described_class.new(unit).groups.first.items.first
  end

  it 'writes structured parameters as a signature' do
    expect(perform_item([{ 'name' => 'article_id', 'splat' => nil, 'has_default' => false }]).text)
      .to eq('perform(article_id)')
  end

  it 'marks optional parameters and splats without inventing a default' do
    params = [{ 'name' => 'key', 'has_default' => false }, { 'name' => 'outcome', 'has_default' => true },
              { 'name' => 'rest', 'splat' => 'single' }, { 'name' => 'options', 'splat' => 'double' }]
    expect(perform_item(params).text).to eq('perform(key, outcome (optional), *rest, **options)')
  end

  it 'keeps legacy string parameters and skips records with no name' do
    expect(perform_item(['id', { 'has_default' => true }, 'mode']).text).to eq('perform(id, mode)')
  end

  it 'agrees with the facts tile' do
    params = [{ 'name' => 'key', 'has_default' => false }, { 'name' => 'outcome', 'has_default' => true }]
    unit = { 'type' => 'job', 'metadata' => { 'perform_params' => params } }
    row = WoodsMap::UnitFacts.new(unit).tile[:rows].assoc('perform params').last
    expect(perform_item(params).text).to eq("perform(#{row})")
  end
end
