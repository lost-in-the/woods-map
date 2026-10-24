# frozen_string_literal: true

RSpec.describe WoodsMap::CommitStrip do
  let(:now) { Time.utc(2026, 10, 18, 12) }

  it 'counts commits per week across the window and marks the last four weeks hot' do
    dates = ['2026-10-15T09:00:00+00:00', '2026-10-14T09:00:00+00:00', '2026-08-01T08:00:00+00:00',
             '2025-01-01T00:00:00+00:00']
    strip = described_class.new(dates, days: 365, now: now)

    expect(strip).to have_attributes(step: 7, bucket_count: 53, total: 3, recent_total: 2, peak: 2)
    expect(strip.buckets.last).to have_attributes(count: 2, recent: true, height: described_class::HEIGHT,
                                                  last: now.to_date)
    expect(strip.buckets.first.recent).to be(false)
  end

  it 'uses days for a short window and keeps every bar inside the view box' do
    strip = described_class.new(['2026-10-18T01:00:00Z'], days: 30, now: now)

    expect(strip).to have_attributes(step: 1, bucket_count: 30)
    expect(strip.buckets.map(&:x).max + described_class::BAR).to eq(strip.width)
    expect(strip.buckets.last.label(strip.step)).to eq('1 commit, day 2026-10-18')
  end

  it 'places a mark for each generation extracted inside the window and labels the axis by quarter' do
    strip = described_class.new([], days: 365, now: now,
                                    generations: [[41, '2026-10-01T00:00:00Z'], [2, '2020-01-01T00:00:00Z']])

    expect(strip.marks.map(&:number)).to eq([41])
    expect(strip.ticks.map(&:last)).to start_with('Oct 2025').and end_with('Oct 2026').and include('Jan 2026', 'Apr')
  end

  it 'draws nothing taller than the strip and nothing for an empty window' do
    strip = described_class.new([], days: 365, now: now)

    expect(strip.peak).to eq(0)
    expect(strip.buckets.map(&:height).uniq).to eq([0])
  end
end
