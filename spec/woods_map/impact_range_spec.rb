# frozen_string_literal: true

RSpec.describe WoodsMap::ImpactRange do
  let(:backend_class) { Class.new.tap { |klass| klass.define_singleton_method(:compare) { |*| nil } } }
  let(:backend) { class_double(backend_class) }
  let(:data) do
    { 'schema_version' => 1, 'range' => { 'from' => { 'generation' => 1 }, 'to' => { 'generation' => 2 } },
      'parameters' => { 'depth' => 2 }, 'changed' => [], 'affected' => [], 'flows' => [],
      'coverage' => { 'complete' => false, 'affected' => 'partial', 'tests' => 'not_computed' },
      'unknowns' => [{ 'kind' => 'node_budget', 'endpoint' => 'to', 'generation' => 2 }] }
  end

  before { allow(described_class).to receive(:backend).and_return(backend) }

  it 'delegates the range to Woods and retains coverage without completing empty sections' do
    allow(backend).to receive(:compare).with(FIXTURE_INDEX, from: 'gen:1', to: 'now')
                                       .and_return(double(to_h: data))
    result = described_class.new(FIXTURE_INDEX, from: 'gen:1')
    expect(result.state).to eq(:available)
    expect(result.data).to equal(data)
    expect(result.data['coverage']).to include('complete' => false, 'tests' => 'not_computed')
  end

  it 'reports missing optional capability on older Woods' do
    allow(described_class).to receive(:backend).and_return(nil)
    expect(described_class.new(FIXTURE_INDEX, from: 'gen:1').state).to eq(:unavailable)
  end

  it 'rejects invalid selectors without exposing backend exception details' do
    allow(backend).to receive(:compare).and_raise(ArgumentError, 'sensitive backend detail')
    result = described_class.new(FIXTURE_INDEX, from: '../elsewhere')
    expect(result.state).to eq(:invalid)
    expect(result.message).not_to include('sensitive backend detail')
  end

  it 'keeps unavailable payload evidence distinct from an empty successful report' do
    allow(backend).to receive(:compare).and_raise(IOError)
    expect(described_class.new(FIXTURE_INDEX, from: 'gen:1').state).to eq(:error)
  end

  it 'fails closed for unsupported report envelopes' do
    allow(backend).to receive(:compare).and_return(double(to_h: data.merge('schema_version' => 2)))
    expect(described_class.new(FIXTURE_INDEX, from: 'gen:1').state).to eq(:error)
  end

  context 'when loading the optional backend' do
    before do
      hide_const('Woods::Impact::Report')
      allow(described_class).to receive(:backend).and_call_original
    end

    def missing_dependency(path)
      LoadError.new('unavailable dependency').tap do |error|
        error.define_singleton_method(:path) { path }
      end
    end

    it 'identifies an absent entry point as unavailable capability' do
      allow(described_class).to receive(:require).with('woods/impact/report')
                                                 .and_raise(missing_dependency('woods/impact/report'))
      expect(described_class.new(FIXTURE_INDEX, from: 'gen:1').state).to eq(:unavailable)
    end

    it 'reports a broken installed backend as an error' do
      allow(described_class).to receive(:require).with('woods/impact/report')
                                                 .and_raise(missing_dependency('synthetic/dependency'))
      expect(described_class.new(FIXTURE_INDEX, from: 'gen:1').state).to eq(:error)
    end
  end

  it 'passes on Woods\' resolution message, which names retained generations only, with the W-11 limit' do
    error = Class.new(ArgumentError) { def self.name = 'Woods::Impact::ResolutionError' }
    detail = 'Selector "gen:9" does not identify one retained payload; use gen:1, gen:2'
    allow(backend).to receive(:compare).and_raise(error, detail)
    message = described_class.new(FIXTURE_INDEX, from: 'gen:9').message
    expect(message).to start_with('Selector "gen:9" does not identify one retained payload; use gen:1, gen:2. ')
    expect(message).to include('W-11, woods#761')
  end

  describe '.saved' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let(:store_class) do
      Class.new do
        def initialize(_index_dir); end

        def read(_id) = nil
      end
    end
    let(:store) { class_double(store_class) }
    let(:id) { 'a' * 64 }

    before { allow(described_class).to receive(:store).and_return(store) }

    it 'reads the exact bytes through Woods\' store and validates the envelope' do
      reader = instance_double(store_class)
      allow(store).to receive(:new).with(FIXTURE_INDEX).and_return(reader)
      allow(reader).to receive(:read).with(id).and_return(JSON.generate(data))
      result = described_class.saved(FIXTURE_INDEX, id)
      expect([result.state, result.data]).to eq([:available, data])
    end

    it 'refuses anything but a SHA-256 ID before touching the store' do
      allow(store).to receive(:new)
      expect(described_class.saved(FIXTURE_INDEX, '../../etc').state).to eq(:missing)
      expect(store).not_to have_received(:new)
    end

    it 'says a report the store cannot find is missing, not empty' do
      reader = instance_double(store_class)
      allow(store).to receive(:new).and_return(reader)
      allow(reader).to receive(:read).and_raise(IOError, 'Saved impact report is unavailable or unsafe')
      result = described_class.saved(FIXTURE_INDEX, id)
      expect([result.state, result.message]).to eq([:missing, described_class::MESSAGES[:missing]])
    end
  end
end
