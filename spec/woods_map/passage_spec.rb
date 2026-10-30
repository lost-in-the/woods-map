# frozen_string_literal: true

RSpec.describe WoodsMap::Passage do
  def passage(identifier, type: 'controller', action: nil)
    WoodsMap::Repository.open(FIXTURE_INDEX) do |repository|
      described_class.new(repository, repository.unit(identifier, type: type), action: action)
    end
  end

  it 'takes the requested action, or the first one' do
    expect(passage('UsersController', action: 'show').action).to eq('show')
    expect(passage('UsersController', action: 'nope').action).to eq('create')
  end

  it 'reads the route, the declaration and the path params of the action' do
    show = passage('UsersController', action: 'show')
    expect(show.request_label).to eq('GET /users/:id')
    expect(show.declared).to include('file' => 'app/controllers/users_controller.rb', 'line' => 11)
    expect(show.path_params).to eq(['id'])
    expect(show.permitted.first).to include('method' => 'user_params', 'model' => 'user')
  end

  it 'keeps the declared filters and hides the framework ones' do
    show = passage('UsersController', action: 'show')
    expect(show.filters.map(&:name)).to eq(%w[logged_in_user correct_user admin_user])
    expect(show.framework_filter_count).to eq(4)
    expect(show.filters.first.scope).to start_with('only: destroy, edit')
  end

  it 'applies only/except as declared on a generation without the resolved chain' do
    show = passage('UsersController', action: 'show')
    expect(show.filters_for.map(&:name)).to eq([])
    expect(show.filters_for('edit').map(&:name)).to eq(%w[logged_in_user correct_user])
  end

  # W-8 (woods#758): each filter carries the actions it applies to, its owner
  # and whether an if/unless condition still decides it.
  def resolved_passage(action)
    WoodsMap::Repository.open(FIXTURE_INDEX) do |repository|
      unit = repository.unit('UsersController', type: 'controller').deep_dup
      unit['metadata']['filters'] = unit['metadata']['filters'].map do |f|
        f.merge('owner' => 'ActionController::Base', 'applies_to' => unit['metadata']['actions'],
                'applicability' => 'resolved')
      end
      apps = unit['metadata']['filters'].select { |f| f['file'] }
      apps[0].merge!('owner' => 'UsersController', 'applies_to' => %w[edit update], 'applicability' => 'resolved')
      apps[1].merge!('owner' => 'Authenticating', 'applies_to' => %w[create edit], 'applicability' => 'conditional',
                     'unless' => ':api_request?')
      apps[2].merge!('owner' => 'ApplicationController', 'applies_to' => [], 'applicability' => 'resolved')
      described_class.new(repository, unit, action: action)
    end
  end

  it 'applies the published resolved chain when the generation carries it (W-8)' do
    edit = resolved_passage('edit')
    expect(edit).to be_resolved
    expect(edit.filters_for.map(&:name)).to eq(%w[logged_in_user correct_user])
    expect(edit.filters_for('destroy').map(&:name)).to eq([])
    expect(edit.filters_for('create').map(&:name)).to eq(%w[correct_user])
  end

  it 'keeps each filter owner and marks a conditional filter as such' do
    filters = resolved_passage('edit').filters
    expect(filters.map(&:owner)).to eq(%w[UsersController Authenticating ApplicationController])
    expect(filters.map(&:conditional?)).to eq([false, true, false])
    expect(filters[1].condition).to eq('unless: :api_request?')
    expect(filters[0].condition).to be_nil
  end

  it 'falls back to declared scopes on a generation without the resolved chain' do
    expect(passage('UsersController', action: 'edit')).not_to be_resolved
    expect(passage('UsersController', action: 'edit').filters.map(&:owner)).to all(be_nil)
  end

  # Woods publishes who wrote each filter (`origin`, woods#936): a gem's filter
  # such as Devise's authenticate_user! is neither the application's nor the framework's.
  def origin_passage(action)
    WoodsMap::Repository.open(FIXTURE_INDEX) do |repository|
      unit = repository.unit('UsersController', type: 'controller').deep_dup
      filters = unit['metadata']['filters']
      filters.each { |f| f['origin'] = f['file'] ? 'app' : 'framework' }
      filters << { 'kind' => 'before', 'filter' => 'authenticate_user!', 'origin' => 'gem' }
      filters << { 'kind' => 'before', 'filter' => 'set_locale_from_rails', 'origin' => 'framework' }
      filters << { 'kind' => 'before', 'filter' => '#<Proc app/controllers/users_controller.rb:7>', 'origin' => 'app' }
      described_class.new(repository, unit, action: action)
    end
  end

  it 'reads the published origin: a gem filter listed as a gem\'s, never as the application\'s' do
    show = origin_passage('show')
    expect(show).to be_origin
    expect(show.filters.map(&:name)).to eq(%w[logged_in_user correct_user admin_user authenticate_user!])
    expect(show.filters.map(&:origin)).to eq(%w[app app app gem])
    expect(show.filters.map(&:gem?)).to eq([false, false, false, true])
  end

  it 'hides the framework\'s filters and every proc, counted by origin' do
    show = origin_passage('show')
    expect(show.hidden_filter_counts).to eq('framework' => 5, 'app' => 1)
    expect(show.framework_filter_count).to eq(6)
  end

  it 'recognises framework filters by name on a generation without origin' do
    show = passage('UsersController', action: 'show')
    expect(show).not_to be_origin
    expect(show.hidden_filter_counts).to eq({})
    expect(show.filters.map(&:origin)).to all(be_nil)
  end

  it 'ties the templates to the action through the view_render edge and follows their partials' do
    show = passage('UsersController', action: 'show')
    expect(show.action_templates.map(&:identifier)).to eq(['users/show.html.erb'])
    expect(show.instance_variables_read).to contain_exactly('@microposts', '@user')
    partials = show.templates - show.action_templates
    expect(partials.map(&:identifier)).to contain_exactly('shared/_stats.html.erb', 'users/_follow_form.html.erb')
    expect(partials.map(&:unit)).to all(be_nil)
  end

  it 'names the model and event of the callback ladder from the permitted params and the action' do
    create = passage('UsersController', action: 'create')
    expect(create.ladder_model['identifier']).to eq('User')
    expect(create.ladder_event).to eq('create')
    expect(passage('UsersController', action: 'show').ladder_event).to be_nil
  end

  it 'emits a numbered sequence diagram of the passage' do
    mermaid = passage('UsersController', action: 'edit').mermaid
    expect(mermaid).to start_with("sequenceDiagram\n  autonumber")
    expect(mermaid).to include('Browser->>C: GET /users/:id/edit', 'C->>C: before logged_in_user', 'C-->>Browser: html')
  end

  it 'reads the action and filter assigns from the per-action facts (W-7)' do
    edit = passage('UsersController', action: 'edit')
    expect(edit.facts.assigns_by('correct_user').pluck('ivar')).to eq(['@user'])
    expect(edit.facts.assigned).to include('@user')
    expect(edit.action_templates.map(&:identifier)).to eq(['users/edit'])
    expect(passage('UsersController', action: 'show').action_templates.map(&:identifier)).to eq(['users/show.html.erb'])
  end

  it 'flags an instance variable a template reads that neither the action nor its filters assign' do
    mail = passage('MailingListMailer', type: 'mailer', action: 'new_post')
    expect(mail.flags.map(&:to_h)).to eq([{ ivar: '@preferences', template: 'mailing_list_mailer/new_post.html.erb' }])
    expect(mail.declared).to include('file' => 'app/mailers/mailing_list_mailer.rb', 'line' => 5)
    expect(passage('UsersController', action: 'show').flags).to eq([])
  end

  it 'raises no flag and says so when the index has no facts' do
    WoodsMap::Repository.open(FIXTURE_INDEX) do |repository|
      unit = repository.unit('UsersController', type: 'controller').deep_dup
      unit['metadata'].delete('action_facts')
      expect(described_class.new(repository, unit, action: 'show').flags).to be_nil
    end
  end

  it 'reads a mailer action from its templates' do
    mail = passage('UserMailer', type: 'mailer', action: 'account_activation')
    expect(mail).to be_mailer
    expect(mail.request_label).to eq('deliver account_activation')
    templates = %w[user_mailer/account_activation.html.erb user_mailer/account_activation.text.erb]
    expect(mail.action_templates.map(&:identifier)).to eq(templates)
    expect(mail.formats).to eq(%w[html text])
  end

  it 'reads a mailer layout and keeps its framework callbacks out of the filters' do
    mail = passage('UserMailer', type: 'mailer', action: 'account_activation')
    expect(mail.layout).to eq('mailer')
    expect(mail.filters).to eq([])
  end
end
