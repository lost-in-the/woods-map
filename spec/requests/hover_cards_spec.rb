# frozen_string_literal: true

require_relative '../support/hover_card_index'

RSpec.describe 'Hover cards on references', type: :request do
  include HoverCardIndex

  def card(href)
    template = html_response_document.at_css(%(template[data-card-target="card"][data-href="#{href}"]))
    template && Nokogiri::HTML.fragment(template.inner_html)
  end

  def facts(fragment)
    fragment.css('dt').map(&:text).zip(fragment.css('dd').map { |dd| dd.text.squish }).to_h
  end

  it 'carries one card per linked unit with the page, keyed by the link it describes' do
    get '/woods/units/model/Caller'
    hrefs = html_response_document.css('.cv .src a').pluck('href')
    templates = html_response_document.css('template[data-card-target="card"]').pluck('data-href')
    expect(templates).to eq(hrefs.uniq)
    expect(html_response_document.at_css('.body')['data-controller'].split).to include('card')
  end

  it 'shows type, path, PageRank place, last author and churn from the graph and metadata.git' do
    get '/woods/units/model/Caller'
    widget = card('/woods/units/model/Domain::Widget')
    expect(widget.at_css('.hch').text.squish).to eq('Domain::Widget model')
    expect(facts(widget)).to include('path' => 'app/models/synthetic.rb', 'PageRank' => '#1 of 4, 0.4000',
                                     'churn' => '12 commits hot')
    expect(facts(widget)['last']).to start_with('Ada <Lovelace>, ').and end_with('2026-10-20')
    expect(widget.css('abbr, [title], .info, script')).to be_empty
  end

  it 'names what the index did not record instead of guessing' do
    get '/woods/units/model/Caller'
    expect(facts(card('/woods/units/model/Gadget')))
      .to eq('path' => 'no file in the index', 'PageRank' => '#4 of 4, 0.0500', 'last' => 'not recorded',
             'churn' => 'not recorded')
  end

  it 'keeps the source links working without JavaScript' do
    get '/woods/units/model/Caller'
    get html_response_document.at_css('.cv .src a')['href']
    expect(response).to have_http_status(:ok)
  end
end
