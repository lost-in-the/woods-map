# frozen_string_literal: true

RSpec.describe WoodsMap::UnitPage do
  let(:repository) { instance_double(WoodsMap::Repository, graph: {}) }

  def facts(type, metadata)
    unit = { 'identifier' => 'Example', 'type' => type, 'metadata' => metadata }
    described_class.new(repository, unit).tiles.first
  end

  it 'shows a job queue and declared error handlers without inferring a default queue' do
    tile = facts('job', { 'queue' => 'mail', 'retry_on' => ['Net::ReadTimeout'], 'discard_on' => [] })
    expect(tile[:eyebrow]).to eq('Job')
    expect(tile[:rows]).to include(%w[queue mail], ['retry on', 'Net::ReadTimeout'],
                                   ['discard on', 'none recorded'], ['scheduled', 'not recorded'])
  end

  it 'shows mailer actions, template counts and delivery metadata' do
    tile = facts('mailer', { 'actions' => ['welcome'], 'delivery_method' => 'smtp',
                             'templates' => { 'welcome' => %w[welcome.html.erb welcome.text.erb] } })
    expect(tile[:rows]).to include(%w[actions welcome], %w[templates 2], %w[delivery smtp])
  end

  it 'shows a template as published, without treating lexical ivars as runtime values' do
    tile = facts('view_template', { 'template_engine' => 'erb', 'is_partial' => false,
                                    'instance_variables' => ['@user'], 'partials_rendered' => ['users/card'] })
    expect(tile[:rows]).to include(%w[engine erb], %w[partial no], ['ivar mentions', '@user'],
                                   ['partials', 'users/card'])
  end

  it 'shows concern methods and counts recorded callback declarations' do
    tile = facts('concern', { 'concern_scope' => 'model', 'uses_active_support' => true,
                              'instance_methods' => ['publish'], 'callbacks_defined' => [{ 'type' => 'after_save' }] })
    expect(tile[:rows]).to include(%w[scope model], %w[ActiveSupport yes], ['instance methods', 'publish'],
                                   %w[callbacks 1])
  end

  it 'shows serializer fields and recorded association counts' do
    tile = facts('serializer', { 'serializer_type' => 'ams', 'wrapped_model' => 'User',
                                 'attributes' => %w[id name], 'associations' => [{ 'name' => 'posts' }] })
    expect(tile[:rows]).to include(%w[kind ams], %w[model User], ['attributes', 'id, name'],
                                   %w[associations 1])
  end

  it 'shows table facts without needing a model or a database connection' do
    tile = facts('database_table', { 'table_name' => 'events', 'database' => 'audit', 'primary_key' => 'uuid',
                                     'column_count' => 0, 'models' => [], 'indexes' => [], 'foreign_keys' => [] })
    expect(tile[:rows]).to include(%w[name events], %w[database audit], ['primary key', 'uuid'],
                                   %w[columns 0], ['models', 'none recorded'], %w[indexes 0])
  end

  it 'preserves published composite primary keys' do
    tile = facts('database_table', { 'primary_key' => %w[region_id id] })
    expect(tile[:rows]).to include(['primary key', 'region_id, id'])
  end

  it 'keeps absent, false and empty metadata distinct' do
    expect(facts('job', {})[:rows]).to include(['queue', 'not recorded'], ['retry on', 'not recorded'])
    expect(facts('job', { 'scheduled' => false, 'retry_on' => [] })[:rows])
      .to include(%w[scheduled no], ['retry on', 'none recorded'])
  end

  it 'reads structured published job parameters without inventing their defaults' do
    tile = facts('job', { 'perform_params' => [{ 'name' => 'id', 'has_default' => false },
                                               { 'name' => 'options', 'splat' => 'double', 'has_default' => true }] })
    expect(tile[:rows]).to include(['perform params', 'id, **options (optional)'])
  end

  it 'preserves generic tiles for other types' do
    expect(described_class.new(repository, { 'identifier' => 'X', 'type' => 'service', 'metadata' => {} }).tiles)
      .to eq([])
  end
end
