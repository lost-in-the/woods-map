# frozen_string_literal: true

require_relative '../support/action_facts_fixture'

# woods-map#47: a dynamic render target or an unresolved partial leaves the
# templates behind it unknown, so neither the passage nor the impact rule may
# certify zero unassigned-ivar mentions.
RSpec.describe WoodsMap::UnassignedIvarRule do
  include ActionFactsFixture

  def show_owner(renders)
    action_owner(facts: { 'show' => action_entry(renders: renders) })
  end

  def passage(repository, owner)
    WoodsMap::Passage.new(repository, owner, action: 'show')
  end

  def interpolated
    'shared/#{variant}' # rubocop:disable Lint/InterpolationCheck
  end

  def partial_repository
    template = action_template(ivars: ['@missing'])
    template['metadata']['unresolved_partials'] = [
      { 'kind' => 'interpolation', 'name' => interpolated },
      { 'kind' => 'caller_prefix', 'name' => 'card', 'candidates' => %w[a/_card.html.erb b/_card.html.erb] }
    ]
    owner = show_owner([{ 'template' => 'widgets/show' }])
    [action_repository([owner, template]), owner]
  end

  it 'marks a dynamic render target incomplete on the passage and the impact rule, naming it' do
    owner = show_owner([{ 'object' => 'params[:template]', 'line' => 3, 'method' => 'show',
                          'file' => 'app/controllers/widgets_controller.rb' }])
    repository = action_repository([owner])
    widget = passage(repository, owner)
    expect([widget.flags, widget.coverage_complete?]).to eq([[], false])
    expect(widget.unresolved_renders.map(&:to_h)).to contain_exactly(
      a_hash_including(kind: 'render target', name: 'params[:template]', where: 'WidgetsController#show', line: 3)
    )
    expect(ivar_result(action_review(repository, 'WidgetsController')))
      .to eq('0 findings; incomplete: 0 actions, 0 templates, 1 dynamic render target')
  end

  it 'marks a mailer computing its template name incomplete' do
    owner = show_owner([{ 'object' => 'mail(template_name: kind)', 'mail' => true, 'line' => 3, 'method' => 'show' }])
    owner['type'] = 'mailer'
    expect(passage(action_repository([owner]), owner)).not_to be_coverage_complete
  end

  it 'keeps format, head and redirect responses complete' do
    owner = show_owner([{ 'format' => 'json', 'line' => 3 }, { 'head' => 'no_content', 'line' => 4 }])
    owner['metadata']['action_facts']['show']['redirects'] = [{ 'target' => 'root_url', 'line' => 5 }]
    repository = action_repository([owner])
    expect(passage(repository, owner)).to be_coverage_complete
    expect(passage(repository, owner).unresolved_renders).to eq([])
    expect(ivar_result(action_review(repository, 'WidgetsController'))).to eq(0)
  end

  it 'counts unresolved partials as passage limits and keeps the findings of known templates' do
    repository, owner = partial_repository
    widget = passage(repository, owner)
    expect(widget.flags.map(&:ivar)).to eq(['@missing'])
    expect(widget.missing_template_facts).to eq([])
    expect(widget.unresolved_renders.map { |u| [u.kind, u.name, u.where] })
      .to eq([['interpolation', interpolated, 'widgets/show.html.erb'], %w[caller_prefix card widgets/show.html.erb]])
  end

  it 'reports unresolved partials as incomplete coverage and unknowns on the impact page' do
    review = action_review(partial_repository.first, 'WidgetsController')
    expect(review.findings.map(&:where)).to eq(['widgets/show.html.erb'])
    expect(ivar_result(review)).to eq('1 finding; incomplete: 0 actions, 0 templates, 2 unresolved partials')
    expect(review.unknowns.map(&:kind)).to eq(['unresolved partial', 'unresolved partial'])
    expect(review.unknowns.last.why).to include('card (caller_prefix', 'a/_card.html.erb')
  end

  it 'lists a dynamic render target among the impact unknowns' do
    owner = show_owner([{ 'object' => '@widget', 'line' => 3, 'method' => 'show' }])
    review = action_review(action_repository([owner]), 'WidgetsController')
    expect(review.unknowns.map { |u| [u.kind, u.where, u.why] })
      .to eq([['dynamic render', 'WidgetsController#show', 'render @widget']])
  end
end
