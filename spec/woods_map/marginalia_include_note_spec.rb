# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WoodsMap::Marginalia do
  def note_for(written, inlined)
    unit = { 'metadata' => { 'inlined_concerns' => inlined } }
    described_class.new(unit, lifecycle: nil).send(:include_note, written)
  end

  it 'marks a namespaced include inlined when the index records the full name' do
    note = note_for('Canopy::MoneyColumns', ['Canopy::MoneyColumns'])

    expect(note.text).to eq('concern Canopy::MoneyColumns, inlined below')
    expect(note.layer).to eq('resolved ancestors')
  end

  it 'matches an include written relative to its namespace against the full name' do
    expect(note_for('MoneyColumns', ['Canopy::MoneyColumns']).text).to end_with('inlined below')
  end

  it 'matches a rooted include' do
    expect(note_for('::Canopy::MoneyColumns', ['Canopy::MoneyColumns']).text).to end_with('inlined below')
  end

  it 'still reads an index written before full names were recorded' do
    expect(note_for('Canopy::MoneyColumns', ['MoneyColumns']).text).to end_with('inlined below')
  end

  it 'does not take a same-short-name concern in another namespace for this one' do
    note = note_for('Canopy::MoneyColumns', ['Ledger::MoneyColumns'])

    expect(note.text).to eq('concern Canopy::MoneyColumns, not in the index')
    expect(note.layer).to be_nil
  end
end
