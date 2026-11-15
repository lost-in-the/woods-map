# frozen_string_literal: true

require_relative '../support/trail_index'

RSpec.describe 'Trail reading walkthrough', type: :request do
  include TrailIndex

  def walkthrough
    get '/woods/trail', params: { pin: %w[job:NotifySubscribersJob mailer:MailingListMailer job:Missing], gen: 1 }
    html_response_document.at_css('[aria-labelledby=trail-walkthrough]')
  end

  it 'offers a source-backed reading order without claiming runtime execution' do
    section = walkthrough
    expect(section).not_to be_nil
    expect(section.text).to include('Reading walkthrough', 'Reading order, not an execution trace', 'gen 1')
    expect(section.css('h3').map(&:text)).to eq(['1. NotifySubscribersJob', '2. MailingListMailer', '3. Missing'])
  end

  it 'renders escaped published source and keeps missing pins visible' do
    section = walkthrough
    expect(section.css('pre').first.text).to include('class NotifySubscribersJob')
    expect(section.text).to include('Not present in this generation')
    expect(section.css('a').pluck('href')).to include('#walkthrough-2')
  end

  it 'escapes source markup rather than executing it' do
    rewrite_source(1, '<script>alert("source")</script>')
    section = walkthrough
    expect(section.css('script')).to be_empty
    expect(section.at_css('pre').text).to eq('<script>alert("source")</script>')
  end

  it 'reads retained source while labeling the current-unit navigation honestly' do
    FileUtils.cp_r(trail_root.join('payloads/gen-1'), trail_root.join('payloads/gen-2'))
    rewrite_source(1, 'retained source')
    rewrite_source(2, 'current source')
    trail_root.join('generation.json').write({ number: 2, token: 'walkthrough2',
                                               payload: 'payloads/gen-2' }.to_json)
    section = walkthrough
    expect(section.at_css('pre').text).to eq('retained source')
    expect(section.text).to include('unit page reads the current generation')
    expect(html_response_document.at_css('a[href="#trail-walkthrough"]')).not_to be_nil
  end

  def rewrite_source(generation, source)
    path = trail_root.glob("payloads/gen-#{generation}/jobs/NotifySubscribersJob_*.json").first
    unit = JSON.parse(path.read).merge('source_code' => source)
    path.write(unit.to_json)
  end

  it 'does not show a walkthrough without pins' do
    get '/woods/trail', params: { entry: 'NotifySubscribersJob' }
    expect(html_response_document.at_css('[aria-labelledby=trail-walkthrough]')).to be_nil
  end
end
