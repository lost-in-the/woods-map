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
end
