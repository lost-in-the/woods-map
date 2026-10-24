# frozen_string_literal: true

RSpec.describe WoodsMap::FreshnessHelper, type: :helper do
  describe '#freshness_detail' do
    it 'names what the quick check saw and what Woods could not verify' do
      report = { 'state' => 'unknown', 'counts' => { 'added' => 0, 'changed' => 0, 'removed' => 0 },
                 'metrics' => { 'visited_files' => 160 },
                 'reasons' => %w[unverified_boot_boundary unverified_consumption_scopes] }
      expect(helper.freshness_detail(report))
        .to eq('160 files checked, no drift seen; the extraction did not run through woods-extract, so the files ' \
               'read while Rails booted are unverified, some extractors could not record every file they read')
    end

    it 'counts the drift when there is some' do
      report = { 'state' => 'drifted', 'counts' => { 'added' => 1, 'changed' => 2, 'removed' => 0 } }
      expect(helper.freshness_detail(report)).to eq('1 added, 2 changed')
    end

    it 'is nil without a report' do
      expect(helper.freshness_detail(nil)).to be_nil
    end

    # A quick check that stopped early still says how much it read.
    it 'says how much of the recorded baseline the check verified when Woods reports it' do
      report = { 'state' => 'unknown', 'counts' => { 'added' => 0, 'changed' => 0, 'removed' => 0 },
                 'coverage' => { 'recorded_files' => 177, 'verified_files' => 120 },
                 'reasons' => %w[scan_time_budget incomplete_verification] }
      expect(helper.freshness_detail(report))
        .to eq('no drift in 120 of 177 recorded files; the quick check stopped at its time limit, ' \
               'not every recorded file was read')
    end
  end

  describe '#freshness_reasons' do
    it 'puts every reason Woods gives in plain words, and keeps unknown ones as written' do
      report = { 'reasons' => %w[unverified_boot_boundary unverified_consumption_scopes something_new] }
      expect(helper.freshness_reasons(report)).to eq(
        ['the extraction did not run through woods-extract, so the files read while Rails booted are unverified',
         'some extractors could not record every file they read', 'something new']
      )
    end
  end

  describe '#freshness_words' do
    it 'maps every state to a glyph class and words' do
      expect(helper.freshness_words('current')).to eq(['fresh', 'index current'])
      expect(helper.freshness_words('nonsense')).to eq(['dim', 'freshness unknown'])
    end

    it 'says no drift was seen when an unknown check found none in what it read' do
      report = { 'state' => 'unknown', 'counts' => { 'added' => 0, 'changed' => 0, 'removed' => 0 },
                 'coverage' => { 'recorded_files' => 177, 'verified_files' => 120 } }
      expect(helper.freshness_words('unknown', report)).to eq(['dim', 'no drift seen'])
      expect(helper.freshness_words('unknown', report.merge('coverage' => nil))).to eq(['dim', 'freshness unknown'])
    end
  end
end
