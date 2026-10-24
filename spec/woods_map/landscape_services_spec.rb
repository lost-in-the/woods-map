# frozen_string_literal: true

RSpec.describe WoodsMap::LandscapeServices do
  let(:graph) do
    { 'edges' => { 'ChargesController' => [{ 'target' => 'Stripe', 'via' => 'service_call' },
                                           { 'target' => 'Charge', 'via' => 'code_reference' }],
                   'RefundJob' => [{ 'target' => 'Stripe', 'via' => 'service_call' }],
                   'Archive' => [{ 'target' => 'Amazon S3', 'via' => 'service_call' }] } }
  end
  let(:nodes) do
    { 'ChargesController' => { 'container' => 'web' }, 'RefundJob' => { 'container' => 'jobs' },
      'Archive' => { 'container' => 'shared' } }
  end
  let(:gemfile) do
    { 'metadata' => { 'external_services' => [{ 'name' => 'Stripe', 'category' => 'payments', 'gems' => ['stripe'] },
                                              { 'name' => 'Sentry', 'category' => 'monitoring',
                                                'gems' => ['sentry-ruby'] }] } }
  end

  def services(gemfile: self.gemfile)
    described_class.new(graph, gemfile, nodes)
  end

  it 'draws declared and called services, each with its evidence (woods#814)' do
    boxes = services.boxes.map { |b| [b.id, b.name, b.technology, b.description] }
    expect(boxes).to eq([['svc_amazon_s3', 'Amazon S3', 'no client gem in the Gemfile', 'called by 1 unit'],
                         ['svc_sentry', 'Sentry', 'monitoring, gem sentry-ruby', 'client gem declared, no call found'],
                         ['svc_stripe', 'Stripe', 'payments, gem stripe', 'called by 2 units']])
  end

  it 'relates the web and job processes to the services their units call, not shared code' do
    rows = services.relationships.map { |r| [r.from, r.to, r.edges] }
    expect(rows).to contain_exactly(['web', 'svc_stripe', 1], ['jobs', 'svc_stripe', 1])
  end

  it 'says whether the generation publishes services at all' do
    expect(services).to be_published
    plain = described_class.new({ 'edges' => {} }, {}, {})
    expect([plain.published?, plain.boxes]).to eq([false, []])
  end
end
