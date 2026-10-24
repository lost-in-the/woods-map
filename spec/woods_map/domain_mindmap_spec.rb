# frozen_string_literal: true

RSpec.describe WoodsMap::DomainMindmap do
  let(:clusters) do
    [{ 'name' => 'Billing', 'hub' => 'Invoice', 'members' => %w[Charge Invoice Plan(old)] },
     { 'name' => 'Users', 'hub' => 'User', 'members' => (1..10).map { |i| "U#{i}" } + ['User'] }]
  end

  it 'puts the system at the root, each cluster with its hub first and a count of the rest' do
    text = described_class.new(clusters, system_name: 'Blog (main)').mermaid
    expect(text.lines.first(5).map(&:rstrip)).to eq(['mindmap', '  root((Blog main))', '    Billing', '      Invoice',
                                                     '      Charge'])
    expect(text).to include('      Plan old', '      +3 more')
  end

  it 'names the budget instead of drawing too many clusters' do
    stub_const('WoodsMap::DomainMindmap::CLUSTER_BUDGET', 1)
    expect(described_class.new(clusters, system_name: 'Blog').refusal).to include('over the mindmap budget of 1')
  end
end
