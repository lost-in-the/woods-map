# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'

RSpec.describe 'Pinned indexed navigation', type: :request do
  let(:root) { Pathname.new(Dir.mktmpdir('map-navigation')) }

  after { FileUtils.remove_entry(root) }

  before do
    [1, 2].each { |number| write_generation(number) }
    publish(1)
    WoodsMap.configuration.index_dir = root
    WoodsMap::FileTree.reset!
  end

  def publish(number)
    root.join('generation.json').write(JSON.generate('number' => number, 'token' => "synthetic#{number}",
                                                     'payload' => "payloads/gen-#{number}"))
  end

  def write_generation(number)
    payload = root.join("payloads/gen-#{number}")
    FileUtils.mkdir_p(payload.join('models'))
    name = number == 1 ? 'Before' : 'After'
    node = { 'type' => 'model', 'file_path' => 'app/entry.rb' }
    payload.join('manifest.json').write(JSON.generate('total_units' => 1, 'counts' => { 'models' => 1 }))
    payload.join('models/_index.json').write(JSON.generate([{ 'identifier' => name, 'file_path' => 'app/entry.rb' }]))
    payload.join('dependency_graph.json').write(JSON.generate('nodes' => { name => node },
                                                              'file_map' => { 'app/entry.rb' => [name] }))
  end

  def publish_during_read(read, opens)
    allow(WoodsMap::Repository).to receive(:open).and_wrap_original do |original, &block|
      original.call do |repository|
        opens << repository.generation_number
        allow(repository).to receive(:freshness).and_return('state' => 'unknown')
        allow(repository).to receive(read).and_wrap_original do |method, *args|
          publish(2)
          method.call(*args)
        end
        rendered = block.call(repository)
        expect(rendered.to_s).to include("gen #{repository.generation_number}")
      end
    end
  end

  { '/woods/units' => :units, '/woods/files/app/entry.rb' => :file_owners }.each do |url, read|
    it "renders #{url} within one lock while publication changes, then uses current on the next request" do
      opens = []
      publish_during_read(read, opens)
      get url
      expect(response.body.scan(%r{/units/model/(\w+)}).flatten.uniq).to eq(['Before'])
      get url
      expect(response.body.scan(%r{/units/model/(\w+)}).flatten.uniq).to eq(['After'])
      expect(opens).to eq([1, 2])
    end
  end
end
