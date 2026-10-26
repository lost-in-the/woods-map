# frozen_string_literal: true

require_relative '../support/trail_index'

# The Trail (M6, notes/trail.md): design-study scenario 2 from one URL.
RSpec.describe 'Trail', type: :request do
  include TrailIndex

  let(:scenario) do
    { entry: 'NotifySubscribersJob', pin: %w[job:NotifySubscribersJob mailer:MailingListMailer model:Post] }
  end

  def page_for(params = {})
    get '/woods/trail', params: params
    html_response_document
  end

  def rows(html, label)
    html.css("table[aria-label='#{label}'] tbody tr").map { |tr| tr.text.squish }
  end

  it 'offers entries when the board names none' do
    html = page_for
    expect(response).to have_http_status(:ok)
    expect(html.css('a').pluck('href')).to include('/woods/trail?entry=NotifySubscribersJob%23perform',
                                                   '/woods/trail?entry=MailingListMailer%23new_post')
    expect(html.at_css('nav.primary, .bar').text).to include('Trail') if html.at_css('nav.primary, .bar')
  end

  it 'answers 404 with the chooser for an entry the generation lacks' do
    html = page_for(entry: 'NoSuchJob#perform')
    expect(response).to have_http_status(:not_found)
    expect(html.at_css('.empty-state').text).to include('No unit named NoSuchJob')
  end

  it 'follows the job across the delivery into the mailer and its templates, in lanes' do
    require_woods(:mail_deliveries)
    html = page_for(scenario)
    lanes = html.at_css('table[aria-label="Lanes of NotifySubscribersJob#perform"]')
    expect(lanes.css('thead th').map(&:text)).to eq(%w[# model job mailer view])
    boundary = lanes.at_css('tr.bnd').text.squish
    expect(boundary).to include('async hop, new process: MailingListMailer#new_post from NotifySubscribersJob#perform')
      .and include('MailingListMailer.new_post.deliver_later')
    steps = rows(html, 'Steps')
    expect(steps.join("\n")).to include('MailingListMailer#new_post', 'mailing_list_mailer/new_post.html.erb')
  end

  it 'flags the job without retry, the if without else and the unassigned template ivar' do
    require_woods(:mail_deliveries)
    flags = rows(page_for(scenario), 'Flags')
    expect(flags).to include(a_string_including('no retry_on or discard_on', 'NotifySubscribersJob',
                                                'retry_on [], discard_on [] (runtime, W-4)'))
    expect(flags).to include(a_string_including('if without else', 'post.published?'))
    expect(flags).to include(a_string_including('template reads an unassigned ivar', '@preferences'))
  end

  it 'names the W-4 limit instead of flagging when a job has no resilience facts' do
    trail_index(trail_root.tap { |r| FileUtils.rm_rf(r.children) }, resilience: false)
    html = page_for(scenario)
    expect(rows(html, 'Flags').join).not_to include('no retry_on')
    expect(html.css('.trail-limits li').map(&:text).join).to include('need Woods W-4')
  end

  it 'follows a model event into the job and the mailer within the hop budget' do
    require_woods(:model_events, :mail_deliveries)
    html = page_for(entry: 'Post@create')
    steps = rows(html, 'Steps').join("\n")
    expect(steps).to include('Post@create', 'Post#notify_subscribers', 'NotifySubscribersJob#perform',
                             'MailingListMailer#new_post')
    expect(rows(html, 'Flags').join("\n")).to include('before_save set_slug runs only if :title_changed?')
    expect(html.css('.trail-limits li').map(&:text).join).to include('1 callbacks the model does not define')
  end

  it 'lists what the hop budget cuts' do
    require_woods(:model_events, :mail_deliveries)
    budget = page_for(entry: 'Post@create', hops: '1')
    expect(rows(budget, 'Steps').join).not_to include('MailingListMailer#new_post')
    expect(budget.css('.trail-limits li').map(&:text).join).to include('beyond the hop budget of 1')
  end

  it 'keeps the board in a token-free URL of identifiers and generation numbers' do
    html = page_for(scenario.merge(gen: '1', token: nil))
    toggles = html.css('table[aria-label=Steps] a.tool').pluck('href')
    expect(toggles).to all(start_with('/woods/trail?'))
    query = parse_query(URI.parse(toggles.first).query)
    expect(query.keys).to all(match(/\A(entry|pin\[\]|gen|hops)\z/))
    expect(html.at_css('.share code').text).not_to include('token')
  end

  it 'drops malformed pins and says so' do
    html = page_for(entry: 'NotifySubscribersJob', pin: ['nonsense', 'job:NotifySubscribersJob'])
    expect(html.at_css('.banner').text).to include('1 pin not read')
    expect(rows(html, 'Pins').size).to eq(1)
  end

  it 'lists the commits that changed two pinned units together' do
    rows = rows(page_for(scenario), 'Changed together')
    expect(rows).to contain_exactly(a_string_including('a1b2c3d', 'Mail followers in batches', 'NotifySubscribersJob',
                                                       'MailingListMailer'))
  end

  it 'draws the ERD of the pinned models from the ERD chunk renderer' do
    html = page_for(scenario.merge(pin: scenario[:pin] + ['model:User']))
    text = html.at_css('section[aria-labelledby=trail-erd] pre').text
    expect(text).to start_with('erDiagram').and include('"posts"', '"users"', '"posts" }o--|| "users" : "author_id"')
  end

  it 'serves the graph of pinned in the neighbourhood JSON shape' do
    get '/woods/trail/graph', params: { pin: %w[job:NotifySubscribersJob model:Post mailer:MailingListMailer] }
    data = response.parsed_body
    expect(data['schema_version']).to eq(1)
    expect(data['elements']['nodes'].map do |n|
      n['data']['identifier']
    end).to contain_exactly('NotifySubscribersJob', 'Post', 'MailingListMailer')
    expect(data['elements']['edges'].map do |e|
      e['data']['via']
    end).to contain_exactly('code_reference', 'code_reference', 'job_enqueue')
  end

  it 'serves the lanes as Mermaid text (D-25)' do
    require_woods(:mail_deliveries)
    get '/woods/trail.mmd', params: { entry: 'NotifySubscribersJob' }
    expect(response.media_type).to eq('text/plain')
    expect(response.body).to start_with('flowchart LR').and include('-.->|"async hop"|')
  end

  it 'serves the pinned graph and ERD as Mermaid text, and asks for an entry otherwise' do
    get '/woods/trail.mmd', params: { view: 'erd', pin: %w[model:Post] }
    expect(response.body).to start_with('erDiagram')
    get '/woods/trail.mmd', params: { view: 'graph', pin: %w[model:Post job:NotifySubscribersJob] }
    expect(response.body).to include('-->|job_enqueue|')
    get '/woods/trail.mmd'
    expect(response).to have_http_status(:bad_request)
  end

  it 'says when the board names a generation that is no longer retained' do
    html = page_for(scenario.merge(gen: '7'))
    expect(html.at_css('.banner').text).to include('Gen 7 is no longer retained')
  end
end
