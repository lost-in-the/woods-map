# frozen_string_literal: true

require_relative '../support/range_report_fixture'

RSpec.describe WoodsMap::Since do
  include RangeReportFixture

  let(:repository) do
    repo = instance_double(WoodsMap::Repository, generation_number: 1)
    allow(repo).to receive(:graph_node).and_return({ 'type' => 'model' })
    repo
  end

  it 'is absent without a selector and refuses a malformed one before asking Woods' do
    allow(WoodsMap::ImpactRange).to receive(:new)
    expect(described_class.from_param('', index_dir: 'x', repository: repository)).to be_nil
    since = described_class.from_param('gen:1; drop', index_dir: 'x', repository: repository)
    expect([since.available?,
            since.message]).to eq([false, 'Use since=gen:N or a retained commit SHA (7–40 characters).'])
    expect(WoodsMap::ImpactRange).not_to have_received(:new)
  end

  it 'compares the selector with now through Woods and reads the unit records' do
    stub_range_report
    since = described_class.from_param('gen:1', index_dir: 'x', repository: repository)
    expect(WoodsMap::ImpactRange).to have_received(:new).with('x', from: 'gen:1', to: 'now')
    expect(since.change('User', 'model')['status']).to eq('modified')
    expect(since.reach('UsersController', 'controller')['distance']).to eq(1)
    expect(since.reach('Gone', 'service')).to be_nil
  end

  it 'marks an area only when a key it reads moved' do
    stub_range_report
    since = described_class.from_param('gen:1', index_dir: 'x', repository: repository)
    expect(%i[callbacks associations validations].map { |area| since.area_changed?('User', 'model', area) })
      .to eq([true, false, false])
  end

  it 'passes on Woods\' message when the generation is not retained' do
    range = instance_double(WoodsMap::ImpactRange, state: :invalid,
                                                   message: 'Selector "gen:9" does not identify one retained payload')
    allow(WoodsMap::ImpactRange).to receive(:new).and_return(range)
    since = described_class.from_param('gen:9', index_dir: 'x', repository: repository)
    expect([since.available?, since.message]).to eq([false, 'Selector "gen:9" does not identify one retained payload'])
  end
end
