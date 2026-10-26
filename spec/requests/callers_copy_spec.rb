# frozen_string_literal: true

RSpec.describe 'What the callers panel calls a reference' do
  def call(caller, method:, line: 4)
    WoodsMap::Callers::Call.new(caller: caller, caller_type: 'model', method: method, line: line,
                                confidence: 'verified')
  end

  def panel(callers)
    page = Struct.new(:identifier).new('Archivable')
    html = WoodsMap::ApplicationController.render(partial: 'woods_map/units/callers',
                                                  locals: { callers: callers, page: page })
    Nokogiri::HTML.fragment(html)
  end

  it 'counts references, not calls, and labels a methodless site a class reference' do
    fragment = panel(nil => [call('Article', method: nil), call('Invoice', method: nil)],
                     'archive!' => [call('Comment', method: 'archive!')])
    expect(fragment.at_css('#callers-h').text.squish).to include('3 references from 3 units')
    expect(fragment.at_css('#callers-h').text).not_to match(/\bcalls?\b/)
    rows = fragment.css('tbody tr').map { |row| row.css('td').map { |td| td.text.squish } }
    expect(rows).to include(['class reference', 'Article', '4', 'verified span'],
                            ['.archive!', 'Comment', '4', 'verified span'])
  end

  it 'counts a single reference in the singular' do
    expect(panel(nil => [call('Article', method: nil)]).at_css('#callers-h').text.squish)
      .to include('1 reference from 1 unit')
  end
end
