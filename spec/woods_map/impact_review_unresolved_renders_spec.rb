# frozen_string_literal: true

require_relative '../support/action_facts_fixture'

# Woods' RenderTargetResolver publishes `unresolved_renders` as `{ name:, reason: }`
# (lib/woods/extractors/render_target_resolver.rb); the Unknown tab names the render.
RSpec.describe WoodsMap::ImpactReview do
  include ActionFactsFixture

  def unknowns_for(unit)
    action_review(action_repository([unit]), unit['identifier']).unknowns
  end

  it 'names an unresolved component render on a controller with its reason, as Woods publishes it' do
    owner = action_owner
    owner['metadata']['unresolved_renders'] = [{ 'name' => 'Ghost', 'reason' => 'constant_missing' },
                                               { 'name' => 'Helpers', 'reason' => 'not_a_component' }]
    expect(unknowns_for(owner).map { |u| [u.kind, u.where, u.why] }).to eq(
      [['render by name', 'WidgetsController', 'render Ghost (constant missing)'],
       ['render by name', 'WidgetsController', 'render Helpers (not a component)']]
    )
  end

  it 'reads the same facts on a component, with its reason in words' do
    component = { 'identifier' => 'CardComponent', 'type' => 'view_component', 'file_path' => 'app/components/card.rb',
                  'metadata' => { 'unresolved_renders' => [{ 'name' => 'Badge', 'reason' => 'unloaded_scope' }] },
                  'dependencies' => [] }
    expect(unknowns_for(component).map(&:why)).to eq(['render Badge (unloaded scope)'])
  end
end
