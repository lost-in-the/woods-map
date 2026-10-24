# frozen_string_literal: true

require_relative '../support/trail_index'

# The Lifecycle tab on controllers, jobs and mailers (FR-6, woods-map#91,
# notes/entry-lifecycle.md): one entry point's flow in the model chain's views.
RSpec.describe 'Entry lifecycle', type: :request do
  include TrailIndex

  def page_for(path, params = {})
    get path, params: params
    html_response_document
  end

  def operations(html, entry)
    html.css("table[aria-label='Operations of #{entry}'] tbody tr").map { |tr| tr.text.squish }
  end

  it "lists a job's perform with its operations and lines, across the delivery into the mailer" do
    require_woods(:mail_deliveries)
    html = page_for('/woods/units/job/NotifySubscribersJob/lifecycle')
    expect(response).to have_http_status(:ok)
    rows = operations(html, 'NotifySubscribersJob#perform')
    expect(rows.first).to include('NotifySubscribersJob#perform', 'L4 if post.published?', 'deliver_later → MailingListMailer#new_post')
    expect(rows.join("\n")).to include('MailingListMailer#new_post mailer, process 1', 'mailing_list_mailer/new_post.html.erb')
    expect(html.at_css('table[aria-label="Lanes of NotifySubscribersJob#perform"] tr.bnd').text)
      .to include('async hop, new process: MailingListMailer#new_post')
  end

  it 'offers the Trail for the cross-process view and keeps the flags' do
    html = page_for('/woods/units/job/NotifySubscribersJob/lifecycle')
    expect(html.css('a.btn').pluck('href'))
      .to include('/woods/trail?entry=NotifySubscribersJob%23perform&pin%5B%5D=job%3ANotifySubscribersJob')
    expect(operations(html, 'NotifySubscribersJob#perform').first).to include('neither retried nor discarded')
  end

  it 'picks a mailer action and a controller action, the first by default and for an unknown one' do
    mailer = page_for('/woods/units/mailer/MailingListMailer/lifecycle')
    expect(mailer.css('[aria-label=action] a[aria-current]').map(&:text)).to eq(['new_post'])
    controller = page_for('/woods/units/controller/UsersController/lifecycle', action_name: 'nope')
    first = controller.css('[aria-label=action] a').first
    expect(first['aria-current']).to eq('true')
    expect(controller.css('[aria-label=action] a').pluck('href'))
      .to include('/woods/units/controller/UsersController/lifecycle?action_name=create')
  end

  it "runs the model event a controller action's save implies, as the Passage ladder reads it" do
    require_woods(:model_events)
    rows = operations(page_for('/woods/units/controller/UsersController/lifecycle', action_name: 'create'),
                      'UsersController#create')
    expect(rows).to include(a_string_including('User@create', 'save implies User@create'))
  end

  it 'serves each view as Mermaid text (D-25)' do
    require_woods(:mail_deliveries)
    base = '/woods/units/job/NotifySubscribersJob/lifecycle.mmd'
    get base
    expect(response.body).to start_with('sequenceDiagram').and include('-)')
    get base, params: { view: 'flowchart' }
    expect(response.body).to start_with('flowchart TD').and include('-.->|"async hop"|')
    get base, params: { view: 'lanes' }
    expect(response.body).to start_with('flowchart LR')
    get '/woods/units/controller/UsersController/lifecycle.mmd', params: { action_name: 'create' }
    expect(response.media_type).to eq('text/plain')
  end

  it 'counts the entry points on the tab' do
    html = page_for('/woods/units/mailer/MailingListMailer')
    expect(html.at_css('a[href="/woods/units/mailer/MailingListMailer/lifecycle"]').text).to include('1')
  end
end
