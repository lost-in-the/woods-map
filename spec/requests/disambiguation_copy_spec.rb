# frozen_string_literal: true

RSpec.describe 'What the disambiguation list says about its candidates' do
  def popover(candidates)
    ambiguity = WoodsMap::References::Ambiguity.new(id: 'wm-amb-1', text: 'ArticlePolicy', method: nil,
                                                    candidates: candidates)
    html = WoodsMap::ApplicationController.render(partial: 'woods_map/units/disambiguation',
                                                  locals: { ambiguities: [ambiguity] })
    Nokogiri::HTML.fragment(html).at_css('.amb-pop')
  end

  it 'describes two types at one path as indexed types, not two runtime classes' do
    text = popover([{ identifier: 'ArticlePolicy', type: 'policy', path: 'app/policies/article_policy.rb' },
                    { identifier: 'ArticlePolicy', type: 'pundit_policy',
                      path: 'app/policies/article_policy.rb' }]).at_css('.cap').text.squish
    expect(text).to include('2 indexed types', 'app/policies/article_policy.rb')
    expect(text).not_to include('cannot tell which one runs')
  end

  it 'keeps the runtime ambiguity wording for candidates defined at different paths' do
    text = popover([{ identifier: 'Notifier', type: 'service', path: 'app/services/notifier.rb' },
                    { identifier: 'Notifier', type: 'lib', path: 'lib/notifier.rb' }]).at_css('.cap').text.squish
    expect(text).to include('cannot tell which one runs')
  end

  it 'lists every candidate with its type and path either way' do
    list = popover([{ identifier: 'ArticlePolicy', type: 'policy', path: 'app/policies/article_policy.rb' },
                    { identifier: 'ArticlePolicy', type: 'pundit_policy', path: 'app/policies/article_policy.rb' }])
    expect(list.css('li').map { |li| li.text.squish })
      .to eq(['ArticlePolicy policy app/policies/article_policy.rb',
              'ArticlePolicy pundit policy app/policies/article_policy.rb'])
  end
end
