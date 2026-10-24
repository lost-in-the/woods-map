# frozen_string_literal: true

RSpec.describe WoodsMap::SourceDiff do
  let(:args) { { identifier: 'Post', type: 'model', from: 1, to: 2 } }
  let(:backend) { Class.new { def self.compare(*, **); end } }

  before { allow(described_class).to receive(:backend).and_return(backend) }

  it 'passes the typed unit and generation selectors to Woods and keeps its answer unchanged' do
    data = { 'schema_version' => 1, 'status' => 'modified', 'facets' => ['source'], 'categories' => ['behaviour'],
             'source_changes' => { 'hunks' => [{ 'lines' => [] }], 'added_lines' => 1, 'removed_lines' => 0 } }
    allow(backend).to receive(:compare).and_return(data)
    diff = described_class.new('/idx', **args)

    expect(backend).to have_received(:compare)
      .with('/idx', unit: { 'identifier' => 'Post', 'type' => 'model' }, from: 'gen:1', to: 'gen:2')
    expect(diff).to have_attributes(state: :available, status: 'modified', facets: ['source'],
                                    categories: ['behaviour'], hunks: [{ 'lines' => [] }], message: nil)
  end

  it 'names a missing Woods, an unretained generation and an unreadable payload, never an empty diff' do
    allow(described_class).to receive(:backend).and_return(nil)
    expect(described_class.new('/idx', **args)).to have_attributes(state: :unavailable, hunks: [], status: nil)

    allow(described_class).to receive(:backend).and_return(backend)
    allow(backend).to receive(:compare).and_raise(ArgumentError, 'gen:1 is not retained')
    expect(described_class.new('/idx', **args).state).to eq(:invalid)

    allow(backend).to receive(:compare).and_raise(IOError)
    expect(described_class.new('/idx',
                               **args)).to have_attributes(state: :error, message: a_string_including('not empty'))

    allow(backend).to receive(:compare).and_return({ 'schema_version' => 2 })
    expect(described_class.new('/idx', **args).state).to eq(:error)
  end
end
