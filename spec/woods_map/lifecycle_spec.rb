# frozen_string_literal: true

RSpec.describe WoodsMap::Lifecycle do
  let(:unit) do
    {
      'identifier' => 'Post',
      'source_code' => "class Post\n  def set_slug; end\n  def notify; end\nend\n",
      'metadata' => { 'callbacks' => [
        { 'type' => 'after_commit', 'filter' => 'notify', 'kind' => 'after', 'conditions' => { 'on' => ['create'] },
          'side_effects' => { 'jobs_enqueued' => ['NotifySubscribersJob'], 'columns_written' => [] } },
        { 'type' => 'before_save', 'filter' => 'set_slug', 'kind' => 'before',
          'conditions' => { 'if' => ['title_changed?'] }, 'side_effects' => { 'columns_written' => ['slug'] } },
        { 'type' => 'before_save', 'filter' => 'normalize_tags', 'kind' => 'before', 'conditions' => {},
          'side_effects' => {} },
        { 'type' => 'after_validation', 'filter' => '_ensure_no_duplicate_errors', 'kind' => 'after',
          'conditions' => {} },
        { 'type' => 'before_destroy', 'filter' => '#<lambda /gems/activerecord/association.rb:142>',
          'kind' => 'before' },
        { 'type' => 'before_validation', 'filter' => 'normalize_changed_in_place_attributes', 'kind' => 'before' }
      ] }
    }
  end
  let(:lifecycle) { described_class.new(unit, concern_methods: { 'Taggable' => ['normalize_tags'] }) }

  it 'orders the create chain as Rails runs it and numbers the steps' do
    steps = lifecycle.steps('create')
    expect(steps.map(&:filter)).to eq(%w[set_slug normalize_tags notify])
    expect(steps.map(&:n)).to eq([1, 2, 3])
  end

  it 'keeps an on: :create callback off the update chain' do
    expect(lifecycle.steps('update').map(&:filter)).to eq(%w[set_slug normalize_tags])
  end

  it 'hides framework callbacks and procs and counts them as a limit' do
    expect(lifecycle.callbacks.pluck('filter')).to contain_exactly('notify', 'set_slug', 'normalize_tags')
    expect(lifecycle.framework.pluck('filter')).to eq(['normalize_changed_in_place_attributes'])
  end

  it 'names the concern a step comes from, its condition and its effects' do
    step = lifecycle.steps('create').find { |s| s.filter == 'normalize_tags' }
    expect(step.owner).to eq('Taggable')
    slug = lifecycle.steps('create').first
    expect(slug.condition).to eq('if: title_changed?')
    expect(slug.effects).to eq(['writes slug'])
    expect(lifecycle.steps('create').last).to be_async.and be_commit
  end
end
