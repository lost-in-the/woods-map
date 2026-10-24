# frozen_string_literal: true

require_relative '../support/action_facts_fixture'

# Woods publishes, per generation, which units list unresolved renders
# (woods#837). The Unknown tab opens only those units within the radius, and
# every involved unit when the generation does not say (an older writer).
RSpec.describe WoodsMap::ImpactUnknowns do
  include ActionFactsFixture

  let(:owner) do
    action_owner.tap do |unit|
      unit['metadata']['unresolved_renders'] = [{ 'name' => 'Ghost', 'reason' => 'constant_missing' }]
    end
  end
  let(:repository) do
    render = [{ 'target' => 'widgets/show.html.erb', 'via' => 'view_render' }]
    action_repository([owner, action_owner(identifier: 'GadgetsController'), action_template],
                      edges: { 'WidgetsController' => render, 'GadgetsController' => render })
  end
  let(:radius) { WoodsMap::BlastRadius.new(repository, focus: 'widgets/show.html.erb') }

  def renders
    described_class.new(repository, radius, {}).unresolved_renders.map { |u| [u.kind, u.where, u.why] }
  end

  it 'opens only the involved units the generation lists, and names their renders' do
    allow(repository).to receive(:units_with).with(:unresolved_renders).and_return(
      [{ 'identifier' => 'WidgetsController', 'type' => 'controller', 'count' => 1 },
       { 'identifier' => 'ElsewhereController', 'type' => 'controller', 'count' => 3 }]
    )

    expect(renders).to eq([['render by name', 'WidgetsController', 'render Ghost (constant missing)']])
    expect(repository).to have_received(:unit).with('WidgetsController', type: 'controller')
    expect(repository).not_to have_received(:unit).with('GadgetsController', anything)
    expect(repository).not_to have_received(:unit).with('ElsewhereController', anything)
  end

  it 'skips a listed identifier whose listed type is not the one the radius reached' do
    allow(repository).to receive(:units_with).with(:unresolved_renders).and_return(
      [{ 'identifier' => 'WidgetsController', 'type' => 'mailer', 'count' => 1 }]
    )

    expect(renders).to be_empty
    expect(repository).not_to have_received(:unit)
  end

  it 'opens every involved unit when the generation does not summarise renders' do
    allow(repository).to receive(:units_with).with(:unresolved_renders).and_return(nil)

    expect(renders).to eq([['render by name', 'WidgetsController', 'render Ghost (constant missing)']])
    expect(repository).to have_received(:unit).with('GadgetsController', type: 'controller')
  end
end
