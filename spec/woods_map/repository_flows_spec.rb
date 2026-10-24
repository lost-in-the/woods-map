# frozen_string_literal: true

RSpec.describe WoodsMap::RepositoryFlows do
  let(:host) do
    Class.new do
      include WoodsMap::RepositoryFlows

      def initialize(index)
        @index = index
      end
    end
  end

  # Not a verifying double: the Woods this runs against may predate the flow
  # readers (woods#805), and the mixin must answer for both.
  let(:index) { double('Woods::PublishedIndex', index_dir: Pathname(FIXTURE_INDEX)) } # rubocop:disable RSpec/VerifiedDoubles

  def readers(index)
    allow(index).to receive(:respond_to?).with(:flow_entry_points).and_return(true)
    allow(index).to receive(:respond_to?).with(:flow_document).and_return(true)
  end

  it 'reports a Woods without flow readers as unsupported and asks nothing' do
    repository = host.new(index)
    expect([repository.flow_entry_points('User', type: 'model'), repository.flows_state]).to eq([nil, :unsupported])
  end

  it 'answers Woods\' membership and remembers that the generation publishes it' do
    readers(index)
    allow(index).to receive(:flow_entry_points).with('User', type: 'model').and_return(['UsersController#show'])
    repository = host.new(index)
    expect([repository.flow_entry_points('User', type: 'model'), repository.flows_state])
      .to eq([['UsersController#show'], :available])
  end

  it 'keeps "publishes no inverse" apart from "no entry points"' do
    readers(index)
    allow(index).to receive(:flow_entry_points).and_return(nil)
    repository = host.new(index)
    repository.flow_entry_points('User', type: 'model')
    expect(repository.flows_state).to eq(:absent)
  end

  it 'reads a corrupt artifact as unreadable, not as no flows' do
    readers(index)
    allow(index).to receive(:flow_document).and_raise(StandardError, 'corrupt')
    repository = host.new(index)
    expect([repository.flow_document('UsersController#show'), repository.flows_state]).to eq([nil, :unreadable])
  end

  it 'reads each flow document once' do
    readers(index)
    allow(index).to receive(:flow_document).and_return({ 'steps' => [] })
    repository = host.new(index)
    2.times { repository.flow_document('UsersController#show') }
    expect(index).to have_received(:flow_document).once
  end

  it 'reads the fixture\'s published flows when this Woods has the readers' do
    skip 'this Woods has no flow readers (woods#805)' unless Woods::PublishedIndex.method_defined?(:flow_entry_points)

    WoodsMap::Repository.open(FIXTURE_INDEX) do |repository|
      expect(repository.flow_entry_points('User',
                                          type: 'model')).to eq(%w[MicropostsController#create UsersController#show])
      expect(repository.flow_document('UsersController#show')['route']).to eq('verb' => 'GET', 'path' => '/users/:id')
    end
  end
end
