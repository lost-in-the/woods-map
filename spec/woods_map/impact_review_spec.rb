# frozen_string_literal: true

RSpec.describe WoodsMap::ImpactReview do
  def review(focus, depth: 2)
    WoodsMap::Repository.open(FIXTURE_INDEX) do |repository|
      described_class.new(repository, WoodsMap::BlastRadius.new(repository, focus: focus, depth: depth))
    end
  end

  it 'runs the rules one generation allows' do
    v = review('User')
    expect(v.findings.map { |f| [f.rule, f.severity, f.where] })
      .to contain_exactly(['hub touched', 'blocking', 'User'], ['cycle entered', 'note', 'User'])
    expect(v.rules.size).to eq(9)
    expect(v.rules.count { |x| x.result.is_a?(Integer) }).to eq(4)
  end

  it 'names what the other rules need' do
    v = review('User')
    expect(v.rules.find { |x| x.name == 'foreign key dropped' }.result).to eq('needs a range')
    expect(v.rules.find { |x| x.name == 'filter chain changed' }.result).to eq('needs a range')
  end

  it 'runs the unassigned-ivar rule on the per-action facts, from the mailer or from its template' do
    [review('MailingListMailer', depth: 1), review('mailing_list_mailer/new_post.html.erb', depth: 1)].each do |v|
      finding = v.findings.find { |f| f.rule == 'template reads unassigned ivar' }
      expect(finding.where).to eq('mailing_list_mailer/new_post.html.erb')
      expect(finding.evidence).to start_with('mailing_list_mailer/new_post.html.erb mentions @preferences')
    end
    expect(review('UsersController', depth: 1).rules.find { |x| x.name == 'template reads unassigned ivar' }.result)
      .to include('incomplete')
  end

  it 'lists the gaps where no test reaches the focus or a direct dependent' do
    v = review('User')
    expect(v.tests).to eq([])
    expect(v.gaps.map(&:text)).to contain_exactly('User has no mapped test', 'Micropost has no mapped test',
                                                  'Relationship has no mapped test',
                                                  'UsersController has no mapped test')
    expect(v.gaps.find { |g| g.text.start_with?('User ') }.severity).to eq('blocking')
  end

  it 'reports no unknowns when the index resolved everything, and the seven layers' do
    v = review('User')
    expect(v.unknowns).to eq([])
    expect(v.layers.size).to eq(7)
    expect(v.layers.first[1]).to include('gen 1')
  end

  describe 'scope by depth' do
    # Focus Gadget; Widget depends on it; ThingsController on Widget, two hops out.
    let(:graph) do
      { 'nodes' => { 'Gadget' => { 'type' => 'model' }, 'Widget' => { 'type' => 'model' },
                     'ThingsController' => { 'type' => 'controller' } },
        'reverse_via' => {
          'Gadget' => [{ 'source' => 'Widget', 'source_type' => 'model', 'via' => 'belongs_to' }],
          'Widget' => [{ 'source' => 'ThingsController', 'source_type' => 'controller', 'via' => 'code_reference' }],
          'ThingsController' => [{ 'source' => 'things_controller_spec.rb', 'source_type' => 'test_mapping',
                                   'via' => 'test_coverage' }]
        }, 'pagerank' => {} }
    end
    let(:analysis) do
      { 'unresolvable_routes' => [{ 'route' => 'GET /things/:id/archive', 'controller' => 'ThingsController' },
                                  { 'route' => 'GET /elsewhere', 'controller' => 'ElsewhereController' }],
        'volatile_dependencies' => [{ 'from' => 'ThingsController', 'to' => 'Widget', 'via' => 'code_reference' },
                                    { 'from' => 'Unrelated', 'to' => 'Other', 'via' => 'code_reference' }] }
    end
    let(:repository) do
      instance_double(WoodsMap::Repository, graph: graph, graph_analysis: analysis, unit: nil, generation_number: 1,
                                            generation_key: ['impact review spec'])
    end

    def scoped(depth)
      described_class.new(repository, WoodsMap::BlastRadius.new(repository, focus: 'Gadget', depth: depth))
    end

    it 'maps tests to the units within the depth, nearest first' do
      expect(scoped(1).tests).to eq([])
      expect(scoped(2).tests.map { |t| [t.spec, t.reaches] }).to eq([['things_controller_spec.rb', '2 hops away']])
    end

    it 'keeps only the unresolvable routes and volatile edges that name a unit within the depth' do
      expect(scoped(1).unknowns.map(&:kind)).to eq(['volatile dependency'])
      expect(scoped(2).unknowns.map { |u| [u.kind, u.where] })
        .to contain_exactly(['unresolvable route', 'GET /things/:id/archive'],
                            ['volatile dependency', 'ThingsController → Widget'])
    end
  end
end
