# frozen_string_literal: true

RSpec.describe WoodsMap::ComponentsHelper, type: :helper do
  it 'gives an explanation a named native button without submitting a surrounding form' do
    trigger = Nokogiri::HTML.fragment(helper.info_tip('Explanation text')).at_css('button.info')
    expect(trigger).not_to be_nil
    expect(trigger['type']).to eq('button')
    expect(trigger['aria-label']).to eq('Explain')
    expect(trigger['title']).to eq('Explanation text')
  end

  it 'preserves rich tooltip content on the named explanation button' do
    content = '<a href="/help">More detail</a>'
    trigger = Nokogiri::HTML.fragment(helper.info_tip('Fallback', html: content)).at_css('button.info')
    expect(trigger).not_to be_nil
    expect(trigger['data-tip-html']).to eq(content)
    expect(trigger['aria-label']).to eq('Explain')
  end
end
