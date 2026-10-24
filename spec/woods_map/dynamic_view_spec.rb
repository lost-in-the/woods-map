# frozen_string_literal: true

RSpec.describe WoodsMap::DynamicView do
  def with_landscape(&block)
    WoodsMap::Repository.open(WoodsMap::LandscapeIndex.path, &block)
  end

  def step(number, type, filter, effects = {})
    WoodsMap::Lifecycle::Step.new(n: number, type: type, filter: filter, conditions: {}, side_effects: effects,
                                  owner: 'User')
  end

  let(:steps) do
    [step(1, 'before_save', 'downcase_email'),
     step(2, 'after_create_commit', 'announce', 'jobs_enqueued' => ['ApplicationJob'],
                                                'mailers_triggered' => ['UserMailer'])]
  end

  it 'groups a model event by container: the saving process, the database write and the async hops' do
    with_landscape do |repository|
      text = described_class.new(repository).lifecycle(repository.unit('User', type: 'model'), steps, 'create')
      expect(text.lines.first.chomp).to eq('flowchart LR')
      expect(text).to include('subgraph proc ["Process that saves User · web or job runner"]',
                              'subgraph db_primary ["Primary database · postgresql"]',
                              'w[("users · INSERT")]', 's1 -->|"INSERT users, commit"| w', 'w --> s2',
                              'subgraph jobs ["Job runner · solid_queue"]',
                              's2 -.->|"2 · enqueues"| a_ApplicationJob', 's2 -.->|"2 · mails"| a_UserMailer',
                              'a_UserMailer -.->|"delivers"| mail')
      expect(described_class.size(text)).to eq(7)
      expect(described_class.refusal(text)).to be_nil
    end
  end

  it 'draws an action passage in the web process with its model save' do
    with_landscape do |repository|
      unit = repository.unit('UsersController', type: 'controller')
      passage = WoodsMap::Passage.new(repository, unit, action: 'create')
      text = described_class.new(repository).passage(passage, repository.unit('User', type: 'model'), steps, 'create')
      expect(text).to include('subgraph web ["Web process · Rails 8.0.0"]', 'request(["POST /users"])',
                              'action -->|"save User"| s1', 'w --> s2')
      expect(text).not_to include('subgraph proc')
    end
  end

  it 'is unavailable on a generation without container attribution' do
    WoodsMap::Repository.open(FIXTURE_INDEX) do |repository|
      view = described_class.new(repository)
      expect(view).not_to be_attributed
      lifecycle = WoodsMap::Lifecycle.new(repository.unit('User', type: 'model'), dynamic: view)
      expect(lifecycle.views).to eq(%w[sequence flowchart lanes])
    end
  end

  it 'offers the dynamic view in the Lifecycle view control when containers are published' do
    with_landscape do |repository|
      lifecycle = WoodsMap::Lifecycle.new(repository.unit('User', type: 'model'),
                                          dynamic: described_class.new(repository))
      expect(lifecycle.views).to eq(%w[sequence flowchart lanes dynamic])
      expect(lifecycle.diagram('dynamic', 'create')).to include('w[("users · INSERT")]')
      expect(lifecycle.budget('dynamic')).to eq(WoodsMap::Lifecycle::FLOWCHART_BUDGET)
    end
  end
end
