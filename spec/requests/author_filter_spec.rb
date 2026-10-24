# frozen_string_literal: true

require 'cgi'

# Clicking a commit's author filters the timeline to their changes
# (woods-map#92, design-study scenario 2 step 4), on the History tab,
# across the unit's neighbourhood on /woods/history, and on the graph's
# timeline. The author travels in the URL exactly as git recorded it.
RSpec.describe 'Filtering timelines by author', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:sam) { 'Sam Okafor-Whitfield' }

  before do
    WoodsMap::CommitLedger.reset!
    travel_to Time.utc(2026, 10, 18, 12)
  end

  def doc
    html_response_document
  end

  def query(href)
    CGI.parse(URI(href).query.to_s)
  end

  def author_links
    doc.css('a.who').map { |a| [a.text.strip, a['href']] }
  end

  it 'links each author on the History tab to the same tab filtered to them' do
    get '/woods/units/job/ApplicationJob/history'
    link = author_links.find { |text, _| text == sam }
    expect(link).not_to be_nil
    expect(URI(link.last).path).to eq('/woods/units/job/ApplicationJob/history')
    expect(query(link.last)['author']).to eq([sam])
    expect(doc.at_css("a.who[title='#{sam}']")).to be_present
  end

  it 'filters the History tab to the author' do
    get '/woods/units/job/ApplicationJob/history', params: { author: sam }
    rows = doc.css('table[aria-label="Commits"] tbody tr:not(.sub)')
    expect(rows.size).to eq(1)
    expect(rows.first.text).to include(sam)
  end

  it 'offers every author back from the filtered History tab' do
    get '/woods/units/job/ApplicationJob/history', params: { author: sam }
    back = doc.css('a').find { |a| a.text == 'all authors' }
    expect(back['href']).to eq('/woods/units/job/ApplicationJob/history')
  end

  it "links the filtered History tab to the author's commits across the neighbourhood" do
    get '/woods/units/job/ApplicationJob/history', params: { author: sam }
    across = doc.css('a').find { |a| a.text.include?('across the neighbourhood') }
    expect(URI(across['href']).path).to eq('/woods/history')
    expect(query(across['href'])).to include('author' => [sam])
    expect(query(across['href'])['units[]']).to include('job:ApplicationJob', 'mailer:MailingListMailer')
  end

  it 'narrows /woods/history by a picked span and the author together, keeping the author when brushing' do
    get '/woods/history', params: { units: ['job:ApplicationJob', 'model:Micropost'], span: '2026-10-01..2026-10-16',
                                    author: sam }
    authors = doc.css('table[aria-label="Commits"] tbody tr').map { |tr| tr.at_css('.who')&.text }.compact.uniq
    expect(authors).to eq([sam])
    expect(doc.at_css('h2#lanes').text).to include("by #{sam} from 2026-10-01 to 2026-10-16")
    brush = CGI.unescape(doc.at_css('[data-brush-url]')['data-brush-url'])
    expect(brush).to include("author=#{sam}", 'span=__SPAN__')
  end

  it 'narrows the History tab by a picked span and the author together' do
    get '/woods/units/job/ApplicationJob/history', params: { span: '2026-10-01..2026-10-16', author: sam }
    rows = doc.css('table[aria-label="Commits"] tbody tr:not(.sub)')
    expect(rows.map { |tr| tr.at_css('.who')&.text }.uniq).to eq([sam])
  end

  it 'filters /woods/history to the author and links back to every author' do
    get '/woods/history', params: { units: ['job:ApplicationJob', 'model:Micropost'], author: sam }
    expect(response).to have_http_status(:ok)
    authors = doc.css('table[aria-label="Commits"] tbody tr').map { |tr| tr.at_css('.who')&.text }.compact.uniq
    expect(authors).to eq([sam])
    back = doc.css('a').find { |a| a.text == 'all authors' }
    expect(query(back['href'])).not_to have_key('author')
    expect(query(back['href'])['units[]']).to eq(['job:ApplicationJob', 'model:Micropost'])
  end

  it 'treats anything but one short string as no author filter' do
    get '/woods/units/job/ApplicationJob/history', params: { author: [sam] }
    expect(response).to have_http_status(:ok)
    expect(doc.css('a').map(&:text)).not_to include('all authors')
  end

  it "filters the graph's timeline to the author" do
    get '/woods/units/model/Micropost/graph', params: { author: 'Leah Armstrong' }
    expect(response).to have_http_status(:ok)
    rows = doc.css('table[aria-label="Commits touching the units drawn"] tbody tr')
    expect(rows.map { |tr| tr.at_css('.who')&.text }.uniq).to eq(['Leah Armstrong'])
    expect(doc.css('a').map(&:text)).to include('all authors')
  end

  it "keeps the graph's author through the explorer's filter form" do
    get '/woods/units/model/Micropost/graph', params: { author: 'Leah Armstrong' }
    expect(doc.at_css('form input[type=hidden][name=author]')&.[]('value')).to eq('Leah Armstrong')
  end
end
