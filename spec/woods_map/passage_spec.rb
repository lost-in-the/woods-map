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

  it 'applies only/except as declared, never resolved' do
    show = passage('UsersController', action: 'show')
    expect(show.filters_for.map(&:name)).to eq([])
    expect(show.filters_for('edit').map(&:name)).to eq(%w[logged_in_user correct_user])
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
