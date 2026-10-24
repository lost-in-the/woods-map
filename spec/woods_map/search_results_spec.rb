# frozen_string_literal: true

RSpec.describe WoodsMap::SearchResults do
  def with_repository(&block)
    WoodsMap::Repository.open(FIXTURE_INDEX, &block)
  end

  describe 'name search' do
    it 'puts the exact name first and includes the table of the same name' do
      with_repository do |repository|
        hits = described_class.new(repository, 'user', mode: 'name').hits
        expect(hits.first.identifier).to eq('User')
        expect(hits.map(&:identifier)).to include('table:users', 'UsersController')
      end
    end

    def rows(names, type = 'model')
      names.map { |id| { 'identifier' => id, 'type' => type } }
    end

    def answer(options)
      broad = %w[BlueWidgetPart Admin::WidgetsController WidgetsController Widgetry WidgetPart Gadget::Widget]
      if options[:exact_prefix] then rows(%w[WidgetsController Widgetry WidgetPart Widget])
      elsif options[:exact_suffix] then rows(%w[Gadget::Widget])
      elsif options[:types] then rows(%w[table:widgets], 'database_table')
      else rows(broad)
      end
    end

    it 'ranks exact, then short-name, then prefix, then other matches, whatever order the reader answers in' do
      repository = instance_double(WoodsMap::Repository)
      allow(repository).to receive(:search) do |_query, **options|
        { 'results' => answer(options), 'completeness' => { 'status' => 'complete', 'reason' => 'exhausted' } }
      end

      hits = described_class.new(repository, 'Widget', mode: 'name').hits
      expect(hits.map(&:identifier)).to eq(
        %w[Widget Gadget::Widget table:widgets Widgetry WidgetPart WidgetsController Admin::WidgetsController
           BlueWidgetPart]
      )
    end
  end

  describe 'code search' do
    let(:repository) { instance_double(WoodsMap::Repository, status: { 'total_units' => 9_000 }) }

    def stub_search(response, scan_budget: true)
      allow(repository).to receive_messages(search_scan_budget?: scan_budget, search: response)
    end

    it 'asks Woods to read up to every unit of the generation' do
      stub_search({ 'results' => [], 'completeness' => { 'status' => 'complete', 'reason' => 'exhausted' } })
      described_class.new(repository, 'deliver_later', mode: 'code').hits

      expect(repository).to have_received(:search)
        .with('deliver_later', fields: %w[source_code], types: nil, limit: 50, max_scan: 9_000)
    end

    it 'keeps Woods default budget on a Woods without a per-call budget' do
      stub_search({ 'results' => [], 'completeness' => { 'status' => 'complete' } }, scan_budget: false)
      described_class.new(repository, 'deliver_later', mode: 'code').hits

      expect(repository).to have_received(:search).with('deliver_later', fields: %w[source_code], types: nil, limit: 50)
    end

    it 'names the scan budget and how much it read when the scan stopped' do
      stub_search({ 'results' => [], 'partial' => true,
                    'scan' => { 'scanned_units' => 500, 'candidate_units' => 8_000 },
                    'completeness' => { 'status' => 'partial', 'reason' => 'scan_budget' } })
      results = described_class.new(repository, 'deliver_later', mode: 'code')

      expect(results.complete?).to be(false)
      expect(results.stop_reason).to eq("stopped after reading 500 of 8000 units' source (scan budget)")
    end

    it 'has no stop reason when complete' do
      stub_search({ 'results' => [], 'completeness' => { 'status' => 'complete', 'reason' => 'exhausted' } })
      expect(described_class.new(repository, 'x', mode: 'code').stop_reason).to be_nil
    end
  end

  describe 'path search' do
    it 'names the units that own each file' do
      with_repository do |repository|
        hit = described_class.new(repository, 'app/models/user.rb', mode: 'path').hits.first
        expect(hit.owners).to include(%w[User model])
        expect(hit.hits).to eq(hit.owners.size)
      end
    end
  end
end
