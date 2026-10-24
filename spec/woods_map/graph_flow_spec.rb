# frozen_string_literal: true

RSpec.describe WoodsMap::GraphFlow do
  # The fixture's graph with W-13's flow document handed over by the
  # repository, so the overlay is tested whatever Woods the bundle carries.
  def flow(centre: 'Micropost', type: 'model', depth: 1, document: WoodsMap::FlowIndex::DOCUMENT)
    WoodsMap::Repository.open(FIXTURE_INDEX) do |repository|
      allow(repository).to receive(:flow_document).and_return(document)
      described_class.new(repository, WoodsMap::Neighbourhood.new(repository, centre, type: type, depth: depth),
                          WoodsMap::FlowIndex::ENTRY)
    end
  end

  it 'resolves each step to a typed unit; a controller step names its controller' do
    steps = flow.steps
    expect(steps.map { |s| [s.position, s.identifier, s.type] })
      .to eq([[1, 'MicropostsController', 'controller'], [2, 'Micropost', 'model'], [3, 'User', 'model'],
              [4, 'ApplicationJob', 'job']])
    expect(steps.first.unit).to eq('MicropostsController#create')
    expect(steps.first.operations).to eq(2)
  end

  it 'matches each move to a drawn edge in either direction and lists the rest' do
    f = flow
    expect(f.steps.map(&:move)).to eq(%i[first edge edge no_edge])
    expect(f.steps.drop(1).map { |step| step.edge&.via }).to eq(['code_reference', 'belongs_to', nil])
    expect(f.unmatched.map(&:identifier)).to eq(['ApplicationJob'])
  end

  it 'carries the route and the depth the document was assembled to' do
    expect(flow).to have_attributes(route: 'POST /microposts', max_depth: 3)
  end

  it 'gives the canvas only the drawn steps with the ends of the edge that reached them' do
    payload = flow.payload
    expect(payload).to include('entry_point' => 'MicropostsController#create', 'total' => 4)
    expect(payload['steps'].pluck('identifier')).to eq(%w[MicropostsController Micropost User])
    expect(payload['steps'].second).to include('from' => %w[MicropostsController controller],
                                               'to' => %w[Micropost
                                                          model])
    expect(payload['steps'].first['from']).to be_nil
  end

  it 'says nothing was found for an entry point the generation does not list' do
    f = flow(document: nil)
    expect(f).not_to be_found
    expect(f.steps).to be_empty
    expect(f.payload['steps']).to be_empty
  end

  it 'reads the published flow family through Woods when the bundle has the W-13 readers' do
    skip 'this Woods has no flow readers (W-13, woods#805)' unless WoodsMap::FlowIndex.readers?

    WoodsMap::Repository.open(WoodsMap::FlowIndex.path) do |repository|
      expect(%w[User Relationship].map { |id| repository.flow_entry_points(id, type: 'model') })
        .to eq([[WoodsMap::FlowIndex::ENTRY], []])
      expect(repository.flows_state).to eq(:available)
      expect(repository.flow_document(WoodsMap::FlowIndex::ENTRY)['steps'].size).to eq(4)
      expect(repository.flow_document('UsersController#index')).to be_nil
    end
  end

  it 'names why a generation cannot list flows' do
    WoodsMap::Repository.open(WoodsMap::FlowIndex.bare_path) do |repository|
      expected = WoodsMap::FlowIndex.readers? ? :absent : :unsupported
      expect(described_class.entries(repository, 'User', 'model')).to eq(state: expected, entries: [])
    end
  end
end
