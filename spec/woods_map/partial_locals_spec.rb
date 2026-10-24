# frozen_string_literal: true

require_relative '../support/action_facts_fixture'

RSpec.describe WoodsMap::PartialLocals do
  include ActionFactsFixture

  def card(reads: ['post'], dynamic: false)
    action_template(identifier: 'posts/_card.html.erb').tap do |unit|
      unit['metadata'].merge!('locals_read' => reads, 'locals_read_dynamic' => dynamic, 'partial_renders' => [])
    end
  end

  def show(renders)
    action_template(identifier: 'posts/show.html.erb').tap { |unit| unit['metadata']['partial_renders'] = renders }
  end

  def render_of(locals, dynamic: false)
    { 'partial' => 'posts/card', 'target' => 'posts/_card.html.erb', 'locals' => locals, 'implicit_local' => nil,
      'dynamic_locals' => dynamic, 'line' => 2 }
  end

  def locals_for(units, templates = units)
    repository = action_repository(units)
    rows = templates.map do |unit|
      WoodsMap::PassageTemplates::Template.new(identifier: unit['identifier'], unit: unit, role: 'template', depth: 0)
    end
    described_class.new(repository, rows, 'PostsController#show')
  end

  it 'flags a local a template passes that the partial never reads' do
    locals = locals_for([show([render_of(%w[post compact])]), card])
    expect(locals).to be_published
    expect(locals.flags.map(&:to_h))
      .to eq([{ local: 'compact', partial: 'posts/_card.html.erb', from: 'posts/show.html.erb', line: 2 }])
    expect(locals.unchecked).to eq([])
  end

  it 'flags a local the action passes to its own partial render (W-7)' do
    partial = card
    row = WoodsMap::PassageTemplates::Template.new(identifier: 'posts/_card.html.erb', unit: partial, role: 'partial',
                                                   depth: 1, locals: %w[post extra])
    locals = described_class.new(action_repository([partial]), [row], 'PostsController#show')
    expect(locals.flags.map { |f| [f.local, f.from, f.line] }).to eq([['extra', 'PostsController#show', nil]])
  end

  it 'names renders it cannot decide instead of flagging them' do
    haml = action_template(identifier: 'posts/_card.html.erb')
    expect(locals_for([show([render_of(['post'])]), haml]).unchecked.map(&:why))
      .to eq(['the partial publishes no locals it reads (not an ERB template)'])
    expect(locals_for([show([render_of([], dynamic: true)]), card]).unchecked.map(&:why))
      .to eq(['the locals passed are computed'])
    expect(locals_for([show([render_of(['other'])]), card(dynamic: true)]).flags).to eq([])
  end

  it 'reports nothing published on an index made before woods#798' do
    template = action_template(identifier: 'posts/show.html.erb')
    expect(locals_for([template])).not_to be_published
  end
end
