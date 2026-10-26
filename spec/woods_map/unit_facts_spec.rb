# frozen_string_literal: true

RSpec.describe WoodsMap::UnitFacts do
  def rows(metadata)
    described_class.new('type' => 'job', 'metadata' => metadata).tile[:rows].to_h
  end

  it 'labels the job enqueue row as enqueued jobs and names what it leaves out' do
    facts = rows('enqueues_jobs' => [])
    expect(facts).to include('enqueued jobs' => 'none recorded')
    expect(facts).not_to have_key('enqueues')
    expect(facts['not counted']).to include('mail deliveries')
  end

  it 'keeps a missing list distinct from an empty one' do
    expect(rows({})).to include('enqueued jobs' => 'not recorded')
  end

  it 'lists the enqueued jobs a unit publishes' do
    expect(rows('enqueues_jobs' => %w[AJob BJob])).to include('enqueued jobs' => 'AJob, BJob')
  end
end
