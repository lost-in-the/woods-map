# frozen_string_literal: true

require 'json'

RSpec.describe WoodsMap::ImpactFlows do
  let(:flows_dir) { File.join(FIXTURE_INDEX, 'payloads/gen-1/flows') }
  let(:documents) do
    %w[UsersController_show MicropostsController_create].to_h do |name|
      document = JSON.parse(File.read(File.join(flows_dir, "#{name}.json")))
      [document['entry_point'], document]
    end
  end
  let(:inverse) { JSON.parse(File.read(File.join(flows_dir, 'by_unit.json'))) }
  let(:repository) do
    instance_double(WoodsMap::Repository, generation_number: 1, flows_state: :available).tap do |repo|
      allow(repo).to receive(:flow_entry_points) { |id, type:| inverse.dig(id, type) }
      allow(repo).to receive(:flow_document) { |entry| documents[entry] }
      allow(repo).to receive(:graph_node) { |id, type:|
        %w[User UsersController Micropost].include?(id) ? { 'type' => type } : nil
      }
    end
  end

  describe '.for_focus' do
    subject(:flows) do
      described_class.for_focus(repository, roots: [%w[User model]], marks: { %w[UsersController controller] => 1 })
    end

    it 'lists the entry points Woods\' membership records for the focus' do
      expect(flows.rows.map(&:entry_point)).to eq(%w[MicropostsController#create UsersController#show])
      expect(flows.total).to eq(2)
    end

    it 'takes the route from the flow document' do
      expect(flows.rows.last.route).to eq('verb' => 'GET', 'path' => '/users/:id')
    end

    it 'marks the focus step changed and reached steps with their distance' do
      steps = flows.rows.last.steps
      expect(steps.map { |s| [s.label, s.distance, s.linkable] })
        .to eq([['UsersController#show', 1, true], ['User', 0, true]])
      expect(flows.rows.last.changed_steps).to eq(1)
    end

    it 'draws targeted calls, branches and responses, and counts untargeted calls' do
      lines = flows.rows.last.steps.first.lines.map { |line| [line.depth, line.kind, line.text] }
      expect(lines).to eq([[0, :call, 'User.find'], [0, :branch, 'if @user.activated?'], [1, :response, '200 render'],
                           [1, :response, '302 redirect_to'], [0, :framework, '1 untargeted calls']])
    end

    it 'reads no flow document until the rows are asked for' do
      flows.total
      expect(repository).not_to have_received(:flow_document)
    end
  end

  describe '.for_report' do
    let(:report) do
      current = { 'entry_point' => 'UsersController#show', 'route' => { 'verb' => 'GET', 'path' => '/users/:id' },
                  'changed_steps' => [{ 'identifier' => 'User', 'type' => 'model' }], 'generation' => 1,
                  'endpoint' => 'to' }
      historical = { 'entry_point' => 'OldController#gone', 'changed_steps' => [], 'generation' => 0,
                     'endpoint' => 'from' }
      data = { 'changed' => [{ 'identifier' => 'User', 'type' => 'model', 'status' => 'modified' }], 'affected' => [],
               'range' => { 'from' => { 'generation' => 1 }, 'to' => { 'generation' => 1 } },
               'flows' => [current, historical] }
      WoodsMap::RangeReport.new(data, repository: repository)
    end

    it 'keeps the report\'s entry points and draws the pinned generation\'s steps' do
      rows = described_class.for_report(repository, report).rows
      expect(rows.map { |r| [r.entry_point, r.steps_state, r.changed] })
        .to eq([['UsersController#show', :shown, [%w[User model]]], ['OldController#gone', :historical, []]])
    end

    it 'shows no steps for another generation\'s flow' do
      expect(described_class.for_report(repository, report).rows.last.steps).to be_nil
    end
  end

  it 'counts entry points beyond the limit' do
    records = Array.new(described_class::LIMIT + 5) { |i| { 'entry_point' => "C#a#{i}", 'generation' => 2 } }
    flows = described_class.new(repository, records)
    expect([flows.rows.size, flows.total,
            flows.truncated?]).to eq([described_class::LIMIT, described_class::LIMIT + 5, true])
  end
end
