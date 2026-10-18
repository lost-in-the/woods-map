# frozen_string_literal: true

RSpec.describe WoodsMap::UnitsHelper, type: :helper do
  describe '#freshness_detail' do
    it 'names what the quick check saw and what Woods could not verify' do
      report = { 'state' => 'unknown', 'counts' => { 'added' => 0, 'changed' => 0, 'removed' => 0 },
                 'metrics' => { 'visited_files' => 160 },
                 'reasons' => %w[unverified_boot_boundary unverified_consumption_scopes] }
      expect(helper.freshness_detail(report))
        .to eq('160 files checked, no drift seen; unverified boot boundary, unverified consumption scopes')
    end

    it 'counts the drift when there is some' do
      report = { 'state' => 'drifted', 'counts' => { 'added' => 1, 'changed' => 2, 'removed' => 0 } }
      expect(helper.freshness_detail(report)).to eq('1 added, 2 changed')
    end

    it 'is nil without a report' do
      expect(helper.freshness_detail(nil)).to be_nil
    end
  end

  describe '#freshness_words' do
    it 'maps every state to a glyph class and words' do
      expect(helper.freshness_words('current')).to eq(['fresh', 'index current'])
      expect(helper.freshness_words('nonsense')).to eq(['dim', 'freshness unknown'])
    end
  end
end
