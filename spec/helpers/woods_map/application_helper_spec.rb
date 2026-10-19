# frozen_string_literal: true

RSpec.describe WoodsMap::ApplicationHelper, type: :helper do
  let(:now) { Time.utc(2026, 10, 16, 14, 0, 0) }

  def shorthand(time)
    helper.relative_date(time, now).first
  end

  it 'uses git buckets: minutes, hours, days, weeks, months, years' do
    samples = { 30 => 'now', 5 * 60 => '5m', 2 * 3600 => '2h', 3 * 86_400 => '3d', 35 * 86_400 => '5w',
                210 * 86_400 => '7mo', 365 * 86_400 => '1y', 425 * 86_400 => '1y 2mo', 6 * 365 * 86_400 => '6y' }
    expect(samples.keys.index_with { |ago| shorthand(now - ago) }).to eq(samples)
  end

  it 'renders an abbr with the long form as the title (D-15)' do
    html = helper.date_abbr('2026-10-13T14:00:00Z', now: now)
    expect(html).to eq('<abbr class="date" title="3 days ago, 2026-10-13">3d</abbr>')
  end

  it 'renders a dash for an unknown date' do
    expect(helper.date_abbr(nil)).to eq('<span class="dim">—</span>')
    expect(helper.date_abbr('not a date')).to eq('<span class="dim">—</span>')
  end

  it 'shortens a SHA and names an unknown one' do
    expect(helper.short_sha('9f8e7d6c5b4a39281716151413121110')).to eq('9f8e7d6')
    expect(helper.short_sha('unknown')).to eq('unknown')
    expect(helper.short_sha(nil)).to eq('unknown')
  end
end
