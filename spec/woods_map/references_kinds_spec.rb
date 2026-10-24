# frozen_string_literal: true

# One unit, its spans and their targets.
RSpec.describe WoodsMap::References do # rubocop:disable RSpec/MultipleMemoizedHelpers
  let(:repository) { instance_double(WoodsMap::Repository) }
  let(:source) do
    <<~RUBY
      class Post
        before_save :set_slug
        NotifyJob.perform_later(id); Notifier.deliver; Helper.call
        def set_slug; end
      end
    RUBY
  end
  let(:spans) do
    [
      { 'line' => 2, 'column' => 14, 'length' => 9, 'target' => 'Post', 'target_type' => 'model',
        'kind' => 'callback_method', 'confidence' => 'verified', 'method' => 'set_slug' },
      { 'line' => 3, 'column' => 2, 'length' => 9, 'target' => 'NotifyJob', 'target_type' => 'job',
        'kind' => 'constant', 'confidence' => 'verified', 'method' => 'perform_later' },
      { 'line' => 3, 'column' => 31, 'length' => 8, 'kind' => 'constant', 'confidence' => 'ambiguous',
        'method' => 'deliver', 'candidates' => [{ 'target' => 'Admin::Notifier', 'target_type' => 'service' },
                                                { 'target' => 'Notifier', 'target_type' => 'lib' }] },
      { 'line' => 3, 'column' => 49, 'length' => 6, 'target' => 'Helper', 'target_type' => 'poro',
        'kind' => 'constant', 'confidence' => 'static' }
    ]
  end
  let(:unit) do
    { 'identifier' => 'Post', 'type' => 'model', 'source_code' => source,
      'metadata' => { 'references' => spans,
                      'methods' => [{ 'name' => 'set_slug', 'kind' => 'instance', 'line' => 4, 'end_line' => 4,
                                      'visibility' => 'public', 'owner' => 'Post' }] } }
  end
  let(:job) do
    { 'identifier' => 'NotifyJob', 'type' => 'job', 'file_path' => 'app/jobs/notify_job.rb',
      'metadata' => { 'source_line_map' => [[3, 1, 10]],
                      'methods' => [{ 'name' => 'perform_later', 'kind' => 'singleton', 'line' => 5, 'end_line' => 5,
                                      'visibility' => 'public', 'owner' => 'NotifyJob' }] } }
  end
  let(:units) do
    { %w[Post model] => unit, %w[NotifyJob job] => job,
      %w[Admin::Notifier service] => { 'identifier' => 'Admin::Notifier', 'type' => 'service',
                                       'file_path' => 'app/services/admin/notifier.rb' },
      %w[Notifier lib] => { 'identifier' => 'Notifier', 'type' => 'lib', 'file_path' => 'lib/notifier.rb' },
      %w[Helper poro] => { 'identifier' => 'Helper', 'type' => 'poro', 'file_path' => 'app/models/helper.rb' } }
  end
  let(:references) { described_class.new(repository, unit) }
  let(:links) { references.by_source_line(WoodsMap::CompositeSource.new(unit).file_lines).values.flatten }

  before do
    allow(repository).to receive(:unit) { |identifier, type:| units[[identifier, type]] }
  end

  def summary(link)
    link.to_h.slice(:identifier, :type, :kind, :confidence, :method, :line, :popover).compact
  end

  it 'links a callback to the line of its own method, through the method table' do
    expect(summary(links[0])).to eq(identifier: 'Post', type: 'model', kind: 'callback_method',
                                    confidence: 'verified', method: 'set_slug', line: 4)
  end

  it 'links a method call to the file line of the class method it names' do
    expect(summary(links[1])).to eq(identifier: 'NotifyJob', type: 'job', kind: 'constant', confidence: 'verified',
                                    method: 'perform_later', line: 3)
  end

  it 'makes an ambiguous span a popover of every indexed candidate, never a link to one' do
    expect(summary(links[2])).to eq(kind: 'constant', confidence: 'ambiguous', method: 'deliver', popover: 'wm-amb-1')
    expect(references.ambiguities.size).to eq(1)
    ambiguity = references.ambiguities.first
    expect([ambiguity.id, ambiguity.text, ambiguity.method]).to eq(%w[wm-amb-1 Notifier deliver])
    expect(ambiguity.candidates).to eq([
                                         { identifier: 'Admin::Notifier', type: 'service',
                                           path: 'app/services/admin/notifier.rb' },
                                         { identifier: 'Notifier', type: 'lib', path: 'lib/notifier.rb' }
                                       ])
  end

  it 'links a static span to its target, keeping its confidence' do
    expect(summary(links[3])).to eq(identifier: 'Helper', type: 'poro', kind: 'constant', confidence: 'static')
  end

  it 'leaves the class page when a method is not in the table, and drops self-links that go nowhere' do
    job['metadata'].delete('methods')
    unit['metadata']['methods'] = []
    expect(links.map { |link| link.to_h.values_at(:identifier, :line) }).to eq([['NotifyJob', nil], [nil, nil],
                                                                                ['Helper', nil]])
  end

  it 'follows a method a concern owns to the concern, at its own line' do
    job['metadata']['methods'].first['owner'] = 'Notifiable'
    units[%w[Notifiable concern]] = {
      'identifier' => 'Notifiable', 'type' => 'concern',
      'metadata' => { 'methods' => [{ 'name' => 'perform_later', 'kind' => 'singleton', 'line' => 7,
                                      'end_line' => 9, 'owner' => 'Notifiable' }] }
    }
    expect(summary(links[1])).to include(identifier: 'Notifiable', type: 'concern', line: 7)
  end

  it 'needs two valid candidates for an ambiguous span' do
    spans[2]['candidates'] = [{ 'target' => 'Notifier', 'target_type' => 'lib' }]
    expect(links.map(&:confidence)).not_to include('ambiguous')
  end
end
