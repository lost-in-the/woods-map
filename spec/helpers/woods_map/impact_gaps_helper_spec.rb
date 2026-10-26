# frozen_string_literal: true

RSpec.describe WoodsMap::ImpactGapsHelper, type: :helper do
  let(:gap) do
    WoodsMap::ImpactReview::Gap.new(severity: 'note', text: 'Ghost has no mapped test', why: 'w',
                                    layer: 'test_mapping', identifier: 'Ghost', type: '')
  end

  it 'keeps an identity with no typed unit as escaped text and says why' do
    repository = instance_double(WoodsMap::Repository, generation_number: 3)
    allow(helper).to receive(:current_repository).and_return(repository)
    html = helper.gap_text(gap)
    expect(html).to eq('Ghost has no mapped test (not a typed unit in gen 3)')
    expect(html).not_to include('<a')
  end

  it 'offers no Impact action for a unit the dependency graph does not hold' do
    repository = instance_double(WoodsMap::Repository, graph_node: nil)
    allow(helper).to receive(:current_repository).and_return(repository)
    expect(helper.impact_action(instance_double(WoodsMap::UnitPage, identifier: 'Ghost', type: 'model'))).to be_nil
  end
end
