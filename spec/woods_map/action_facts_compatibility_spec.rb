# frozen_string_literal: true

require_relative '../support/action_facts_fixture'

RSpec.describe WoodsMap::ActionFacts do
  include ActionFactsFixture

  it 'retains explicitly named templates and partials missing from the index' do
    owner = action_owner(facts: { 'show' => action_entry(renders: [{ 'template' => 'widgets/show' },
                                                                   { 'partial' => 'shared/_card' }]) })
    passage = WoodsMap::Passage.new(action_repository([owner]), owner, action: 'show')
    expect(passage.templates.map(&:identifier)).to eq(['widgets/show', 'shared/_card'])
    expect(passage.templates.map(&:unit)).to all(be_nil)
    expect(passage.missing_template_facts).to eq(['widgets/show', 'shared/_card'])
  end

  it 'distinguishes an omitted action from a covered action with no assignments or renders' do
    owner = action_owner(actions: %w[show external], facts: { 'show' => action_entry })
    repository = action_repository([owner])
    expect(WoodsMap::Passage.new(repository, owner, action: 'show').flags).to eq([])
    expect(WoodsMap::Passage.new(repository, owner, action: 'external').flags).to be_nil
    expect(ivar_result(action_review(repository, 'WidgetsController'))).to include('incomplete', '1 action')
  end

  it 'does not treat an action entry missing assignment or render metadata as known empty' do
    owner = action_owner(facts: { 'show' => {} })
    expect(described_class.for(owner, 'show')).to be_nil
    expect(ivar_result(action_review(action_repository([owner]), 'WidgetsController'))).to eq('needs W-7')
  end

  it 'keeps an empty action-facts map unavailable for admitted actions' do
    owner = action_owner(facts: {})
    expect(ivar_result(action_review(action_repository([owner]), 'WidgetsController'))).to eq('needs W-7')
  end

  it 'reports mixed owner coverage and retains findings from covered actions' do
    owner = action_owner(facts: { 'show' => action_entry(renders: [{ 'template' => 'widgets/show' }]) })
    legacy = action_owner(identifier: 'LegacyController', facts: nil)
    template = action_template(ivars: ['@missing'])
    review = action_review(action_repository([owner, legacy, template]), %w[WidgetsController LegacyController])
    expect(review.findings.map(&:where)).to eq(['widgets/show.html.erb'])
    expect(ivar_result(review)).to include('1 finding', 'incomplete', '1 action')
  end

  it 'does not certify missing template metadata as known empty' do
    owner = action_owner(facts: { 'show' => action_entry(renders: [{ 'template' => 'widgets/show' }]) })
    template = action_template
    template['metadata'].delete('instance_variables')
    review = action_review(action_repository([owner, template]), 'WidgetsController')
    expect(ivar_result(review)).to include('incomplete', '1 template')
  end

  it 'follows shared partial render callers to their owner without looping' do
    owner = action_owner(facts: { 'show' => action_entry(renders: [{ 'template' => 'widgets/show' }]) })
    card = action_template(identifier: 'shared/_card.html.erb', ivars: ['@missing'])
    template = action_template(dependencies: [{ 'via' => 'render', 'target' => card['identifier'] }])
    edges = { template['identifier'] => [{ 'via' => 'view_render', 'target' => owner['identifier'] },
                                         { 'via' => 'render', 'target' => card['identifier'] }],
              card['identifier'] => [{ 'via' => 'render', 'target' => template['identifier'] }] }
    review = action_review(action_repository([owner, template, card], edges: edges), card['identifier'])
    expect(review.findings.map(&:where)).to eq([card['identifier']])
    expect(ivar_result(review)).to eq(1)
  end

  it 'qualifies lexical template mentions as advisory evidence' do
    owner = action_owner(facts: { 'show' => action_entry(renders: [{ 'template' => 'widgets/show' }]) })
    template = action_template(ivars: ['@obsolete'])
    template['source_code'] = '<%# @obsolete %>'
    finding = action_review(action_repository([owner, template]), 'WidgetsController').findings.first
    expect(finding.severity).to eq('note')
    expect(finding.evidence).to include('mentions', 'no recorded assignment')
    expect(finding.evidence).not_to include('renders nil', 'never assign')
  end

  it 'preserves action lists and method effects while reading additive facts' do
    owner = action_owner
    owner['metadata']['method_effects'] = { 'show' => { 'reads' => ['Widget'] } }
    original = Marshal.dump(owner)
    repository = action_repository([owner])
    expect(WoodsMap::Passage.new(repository, owner, action: 'show').actions).to eq(['show'])
    expect(ivar_result(action_review(repository, owner['identifier']))).to eq(0)
    expect(Marshal.dump(owner)).to eq(original)
  end

  it 'distinguishes known-empty template mentions from unavailable metadata' do
    owner = action_owner(facts: { 'show' => action_entry(renders: [{ 'template' => 'widgets/show' }]) })
    repository = action_repository([owner, action_template])
    expect(ivar_result(action_review(repository, 'WidgetsController'))).to eq(0)
  end

  it 'matches an explicitly qualified template identifier without inventing a format' do
    owner = action_owner(facts: { 'show' => action_entry(renders: [{ 'template' => 'widgets/show.html.erb' }]) })
    template = action_template
    passage = WoodsMap::Passage.new(action_repository([owner, template]), owner, action: 'show')
    expect(passage.action_templates.map(&:unit)).to eq([template])
    expect(passage.missing_template_facts).to eq([])
  end

  it 'keeps deeper partial chains explicitly incomplete at the traversal limit' do
    templates = (0..4).map { |n| action_template(identifier: "shared/_level#{n}.html.erb") }
    templates.each_cons(2) do |parent, child|
      parent['dependencies'] = [{ 'via' => 'render', 'target' => child['identifier'] }]
    end
    owner = action_owner(facts: { 'show' => action_entry(renders: [{ 'template' => 'shared/_level0' }]) })
    repository = action_repository([owner] + templates)
    passage = WoodsMap::Passage.new(repository, owner, action: 'show')
    expect(passage.templates.size).to eq(4)
    expect(passage.missing_template_facts).to eq(['shared/_level4.html.erb'])
    expect(ivar_result(action_review(repository, 'WidgetsController'))).to include('incomplete', '1 template')
  end

  it 'retains convention-based templates and unavailable flags for older indexes' do
    owner = action_owner(facts: nil)
    owner['metadata'].delete('action_facts')
    template = action_template(ivars: ['@missing'])
    edges = { template['identifier'] => [{ 'via' => 'view_render', 'target' => owner['identifier'] }] }
    repository = action_repository([owner, template], edges: edges)
    passage = WoodsMap::Passage.new(repository, owner, action: 'show')
    expect(passage.action_templates.map(&:identifier)).to eq([template['identifier']])
    expect(passage.flags).to be_nil
    expect(ivar_result(action_review(repository, 'WidgetsController'))).to eq('needs W-7')
  end
end
