# frozen_string_literal: true

# M3's exit criterion (woods-map#5): the diagrams match the flow document and
# the model facts. Runs on the fixture, or on any published index with
# WOODS_MAP_EXIT_INDEX=<index dir> (the testbed check in
# docs/design/notes/m3-exit-check.md).
RSpec.describe WoodsMap::M3ExitCheck do
  let(:index) { ENV.fetch('WOODS_MAP_EXIT_INDEX', FIXTURE_INDEX) }
  let(:result) { described_class.run(index) }

  def problems(rows)
    rows.flat_map { |row| row[:problems].map { |problem| "#{row[:entry]}: #{problem}" } }
  end

  it 'draws every step of each entry flow in Woods order, in the sequence, flowchart and lanes' do
    expect(result[:entries]).not_to be_empty
    expect(problems(result[:entries])).to eq([])
  end

  it 'draws each model event with the application callbacks of Woods model event flow, in order' do
    expect(problems(result[:models])).to eq([])
  end

  it 'draws each model with its columns and every direct association to the table its target reads' do
    expect(result[:schema]).not_to be_empty
    expect(problems(result[:schema])).to eq([])
  end
end
