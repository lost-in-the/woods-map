# frozen_string_literal: true

require_relative '../support/action_facts_fixture'

# The rule reads a passage per reached controller action, which at a hub is
# thousands of unit reads; a second view of the same reach reuses the outcome.
RSpec.describe WoodsMap::UnassignedIvarRule do
  include ActionFactsFixture

  let(:owner) { action_owner(facts: { 'show' => action_entry(renders: [{ 'template' => 'widgets/show' }]) }) }
  let(:template) { action_template(ivars: ['@widget']) }
  let(:repository) do
    action_repository([owner, template],
                      edges: { 'WidgetsController' => [{ 'target' => 'widgets/show.html.erb',
                                                         'via' => 'view_render' }] })
  end

  it 'runs once per generation and reach' do
    allow(described_class).to receive(:new).and_call_original
    first = ivar_result(action_review(repository, 'WidgetsController'))
    expect(ivar_result(action_review(repository, 'WidgetsController'))).to eq(first)
    expect(described_class).to have_received(:new).once
  end

  it 'runs again for another reach' do
    action_review(repository, 'WidgetsController').rules
    allow(described_class).to receive(:new).and_call_original
    action_review(repository, 'widgets/show.html.erb').rules
    expect(described_class).to have_received(:new).once
  end
end
