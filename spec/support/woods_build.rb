# frozen_string_literal: true

require 'woods/build_identity'

module WoodsMap
  # Stable reader identity for fixture generations, independent of installed Woods.
  module WoodsBuild
    # @param version [String] reader version
    # @param revision [String, nil] reader revision
    # @return [void]
    def stub_woods_build(version: '2.2.0.alpha', revision: nil)
      identity = instance_double(Woods::BuildIdentity, version: version, revision: revision, dirty: false)
      allow(Woods::BuildIdentity).to receive(:current).and_return(identity)
    end
  end
end

RSpec.configure do |config|
  config.include WoodsMap::WoodsBuild
  config.before { stub_woods_build }
end
