# frozen_string_literal: true

require_relative '../support/browser_page'

RSpec.describe WoodsMap::BrowserPage do
  include described_class

  [[390, 200], [640, 900], [960, 900], [1440, 1000]].each do |width, height|
    it "uses exactly #{width} by #{height} CSS pixels" do
      skip 'Set WOODS_MAP_BROWSER to run the Chromium regression' unless ENV['WOODS_MAP_BROWSER']

      runner = 'report({ width: innerWidth, height: innerHeight, scale: devicePixelRatio })'
      result = run_page('<body>viewport</body>', width: width, height: height, runner: runner)
      expect(result).to eq('width' => width, 'height' => height, 'scale' => 1)
    end
  end
end
