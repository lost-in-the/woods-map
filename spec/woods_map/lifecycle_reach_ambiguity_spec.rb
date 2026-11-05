# frozen_string_literal: true

RSpec.describe WoodsMap::LifecycleReach do
  let(:mapper) { Class.new { include WoodsMap::LifecycleReach }.new }

  %i[call async].each do |kind|
    it "does not establish a resolved destination for an ambiguous #{kind}" do
      operation = { type: kind, target: 'Billing', method: 'perform_later',
                    ambiguous_candidates: %w[A::Billing B::Billing] }
      reach = {}
      mapper.send(:map_operations, [operation], 'UsersController#show', 0, reach)
      expect(reach).to be_empty
    end
  end
end
