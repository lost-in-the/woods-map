# frozen_string_literal: true

require 'spec_helper'

# Include notes through the public path: CodeView hands each source line to
# Marginalia#for_line, which dispatches `include` lines by its INCLUDE pattern.
RSpec.describe WoodsMap::Marginalia do
  def note_for(line, inlined)
    unit = { 'metadata' => { 'inlined_concerns' => inlined } }
    described_class.new(unit, lifecycle: nil).for_line(line)
  end

  it 'marks a namespaced include inlined when the index records the full name' do
    note = note_for('  include Canopy::MoneyColumns', ['Canopy::MoneyColumns'])

    expect(note.text).to eq('concern Canopy::MoneyColumns, inlined below')
    expect(note.layer).to eq('resolved ancestors')
    expect(note.link).to eq('Canopy::MoneyColumns')
  end

  it 'matches an include written relative to its namespace against the full name' do
    expect(note_for('  include MoneyColumns', ['Canopy::MoneyColumns']).text).to end_with('inlined below')
  end

  it 'gives a rooted include a note, matched as the exact full name and linked without the root' do
    note = note_for('  include ::Canopy::MoneyColumns', ['Canopy::MoneyColumns'])

    expect(note.text).to eq('concern ::Canopy::MoneyColumns, inlined below')
    expect(note.link).to eq('Canopy::MoneyColumns')
  end

  it 'does not match a rooted top-level name to a namespaced concern' do
    expect(note_for('  include ::MoneyColumns', ['Canopy::MoneyColumns']).text).to end_with('not in the index')
  end

  it 'does not match a rooted name to a deeper constant that ends with it' do
    expect(note_for('  include ::Canopy::MoneyColumns', ['Outer::Canopy::MoneyColumns']).text)
      .to end_with('not in the index')
  end

  it 'does not take a same-short-name concern in another namespace for this one' do
    note = note_for('  include Canopy::MoneyColumns', ['Ledger::MoneyColumns'])

    expect(note.text).to eq('concern Canopy::MoneyColumns, not in the index')
    expect(note.layer).to be_nil
  end

  it 'does not match a namespaced include to a short entry, which may be a different top-level concern' do
    expect(note_for('  include Canopy::MoneyColumns', ['MoneyColumns']).text).to end_with('not in the index')
    expect(note_for('  include ::Canopy::MoneyColumns', ['MoneyColumns']).text).to end_with('not in the index')
  end

  it 'matches an unnamespaced concern exactly' do
    expect(note_for('  include MoneyColumns', ['MoneyColumns']).text).to end_with('inlined below')
  end

  it 'notes a rooted include through CodeView with a real Marginalia' do
    unit = { 'identifier' => 'Payouts::Earning', 'file_path' => 'app/models/payouts/earning.rb',
             'source_code' => "class Payouts::Earning\n  include ::Canopy::MoneyColumns\nend\n",
             'metadata' => { 'inlined_concerns' => ['Canopy::MoneyColumns'] } }
    repository = instance_double(WoodsMap::Repository)
    rows = WoodsMap::CodeView.new(unit, lens: 'written', references: WoodsMap::References.new(repository, unit),
                                        marginalia: described_class.new(unit, lifecycle: nil),
                                        unit_path: ->(identifier, type) { "/units/#{type}/#{identifier}" }).rows

    expect(rows[1].note&.text).to eq('concern ::Canopy::MoneyColumns, inlined below')
  end
end
