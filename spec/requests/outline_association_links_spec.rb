# frozen_string_literal: true

RSpec.describe 'Model outline association links', type: :request do
  def association(name)
    get '/woods/units/model/User?lens=written'
    follow_redirect! if response.redirect?
    response.parsed_body.css('nav.rail li').find { |li| li.text.squish.match?(/\A·#{name} /) }
  end

  it 'links an association to its target model and keeps the association kind beside it' do
    item = association('microposts')
    expect(item.at_css('a')['href']).to eq('/woods/units/model/Micropost')
    expect(item.at_css('.own').text).to eq('has_many Micropost')
  end

  it 'links a through association to the model it reaches' do
    item = association('following')
    expect(item.at_css('a')['href']).to eq('/woods/units/model/User')
    expect(item.at_css('.own').text).to eq('has_many through active_relationships')
  end

  it 'leaves an association whose target the generation does not hold as text' do
    allow(WoodsMap::Outline).to receive(:new).and_wrap_original do |original, unit, **options|
      original.call(unit, **options, links: options[:links].merge(association: ->(_target) {}))
    end
    expect(association('microposts').at_css('a')).to be_nil
  end
end
