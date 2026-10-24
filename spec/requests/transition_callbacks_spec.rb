# frozen_string_literal: true

require_relative '../support/state_machine_index'

# Structured state machine transition callbacks on a model's Lifecycle tab
# (woods#796): per transition, by phase, the method linked to its line.
RSpec.describe 'Transition callbacks', type: :request do
  include TrailIndex
  include StateMachineIndex

  before do
    FileUtils.rm_rf(trail_root.children)
    state_machine_index(trail_root, structured: structured)
    WoodsMap::FileTree.reset!
  end

  let(:structured) { true }

  def page
    get '/woods/units/model/Post/lifecycle'
    html_response_document
  end

  def transitions(html)
    html.css('table[aria-label="Transitions of Post::state_machine_state"] tbody tr')
  end

  it 'draws before and after callbacks on the transitions their scope admits, linked to their lines' do
    rows = transitions(page)
    publish = rows.find { |tr| tr.text.include?('publish') }
    cells = publish.css('td').map { |td| td.text.squish }
    expect(cells.last(3)).to eq(['set_slug writes slug', '—', 'notify_subscribers enqueues NotifySubscribersJob'])
    expect(publish.css('a').pluck('href')).to include('/woods/units/model/Post#L4', '/woods/units/model/Post#L8')
    archive = rows.find { |tr| tr.text.include?('archive') }
    expect(archive.css('td').last.text.squish).to eq('block')
  end

  it 'lists a callback whose scope is not literal apart, and drops the raw lines' do
    html = page
    unplaced = html.at_css('table[aria-label="Callbacks of Post::state_machine_state not tied to a transition"]').text
    expect(unplaced).to include('from not literal', 'audit')
    expect(html.at_css('table[aria-label="Transition callbacks of Post::state_machine_state"]')).to be_nil
  end

  it 'labels the transitions that carry callbacks in the state diagram and its .mmd text' do
    expect(page.css('pre.cmd').map(&:text).join).to include('publish / before set_slug, after notify_subscribers')
    get '/woods/units/state_machine/Post::state_machine_state/lifecycle.mmd'
    expect(response.body).to include('archive / after block')
  end

  context 'with a generation from before structured callbacks' do
    let(:structured) { false }

    it 'keeps the raw lines and the plain transitions table' do
      html = page
      expect(html.at_css('table[aria-label="Transition callbacks of Post::state_machine_state"]').text)
        .to include('after_transition on: :publish, do: :notify_subscribers')
      expect(transitions(html).first.css('td').size).to eq(3)
    end
  end
end
