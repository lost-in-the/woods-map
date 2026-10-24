# frozen_string_literal: true

require_relative '../support/trail_index'

RSpec.describe WoodsMap::LifecycleBuilder do
  include TrailIndex

  def build(entry, hops: 2)
    WoodsMap::Repository.open(trail_root) { |repository| described_class.new(repository, entry, hops: hops) }
  end

  it 'reads a bare job as its perform and a bare single-action mailer as its action' do
    expect(build('NotifySubscribersJob').entry).to eq('NotifySubscribersJob#perform')
    expect(build('MailingListMailer').entry).to eq('MailingListMailer#new_post')
  end

  it 'numbers processes at each async hop and puts each step in its lane' do
    require_woods(:model_events, :mail_deliveries)
    lifecycle = build('Post@create')
    places = lifecycle.steps.to_h { |s| [s.label, [s.lane, s.process, s.via]] }
    expect(places).to include('Post@create' => ['model', 0, :entry], 'Post#notify_subscribers' => ['model', 0, :call],
                              'NotifySubscribersJob' => ['job', 1, :async],
                              'MailingListMailer#new_post' => ['mailer', 2, :delivery],
                              'mailing_list_mailer/new_post.html.erb' => ['view', 2, :template])
    expect(lifecycle.processes.map(&:mechanism)).to eq(%w[NotifySubscribersJob.perform_later
                                                          MailingListMailer.new_post.deliver_later])
  end

  it 'follows a published job_enqueue edge where the flow has no call site, and says so' do
    lifecycle = build('Post#set_slug')
    job = lifecycle.steps.find { |s| s.unit == 'NotifySubscribersJob' }
    expect(job).to have_attributes(via: :graph, process: 1, method_name: 'perform')
    expect(job.hop.mechanism).to eq('job_enqueue edge')
    expect(lifecycle.limits).to include('hops from a graph edge, with no call site in the flow' => 1)
  end

  it 'lists steps past the hop budget instead of dropping them silently' do
    require_woods(:model_events, :mail_deliveries)
    lifecycle = build('Post@create', hops: 1)
    expect(lifecycle.steps.map(&:label)).not_to include('MailingListMailer#new_post')
    expect(lifecycle.beyond.map(&:first)).to include('MailingListMailer#new_post')
  end

  it 'draws the lanes as a flowchart with one subgraph per lane and dashed async hops' do
    require_woods(:mail_deliveries)
    text = build('NotifySubscribersJob').mermaid
    expect(text.lines.first.chomp).to eq('flowchart LR')
    expect(text).to include('subgraph lane_job ["job"]', 'subgraph lane_view ["view"]')
    # The hop starts at the job that delivers the mail, not at the step before it.
    expect(text).to include('s1 -.->|"async hop"| s3')
  end
end
