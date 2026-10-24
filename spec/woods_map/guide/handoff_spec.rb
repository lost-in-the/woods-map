# frozen_string_literal: true

RSpec.describe WoodsMap::Guide::Handoff do
  def handoff(context, cited: [%w[Post model], %w[NotifySubscribersJob job]], generation: 7)
    described_class.new({ 'context' => context }, cited: cited, generation: generation)
  end

  describe 'open as investigation' do
    it 'starts a board from the cited units at the answer\'s generation' do
      expect(handoff({ 'page' => 'code', 'type' => 'model', 'identifier' => 'Post' }).investigation)
        .to eq('pin' => %w[model:Post job:NotifySubscribersJob], 'gen' => 7)
    end

    it 'names the entry the context gives: a job\'s perform, a controller action, the board\'s own' do
      expect(handoff({ 'type' => 'job', 'identifier' => 'NotifySubscribersJob' }).investigation)
        .to include('entry' => 'NotifySubscribersJob#perform')
      expect(handoff({ 'type' => 'controller', 'identifier' => 'PostsController', 'action_name' => 'create' })
               .investigation).to include('entry' => 'PostsController#create')
      expect(handoff({ 'page' => 'trail',
                       'entry' => 'Post@create' }).investigation).to include('entry' => 'Post@create')
    end

    it 'pins the page\'s unit when the answer cites none, and offers nothing without either' do
      expect(handoff({ 'type' => 'model', 'identifier' => 'User' }, cited: []).investigation)
        .to eq('pin' => ['model:User'], 'gen' => 7)
      expect(handoff({}, cited: []).investigation).to be_nil
    end

    it 'keeps at most the Trail\'s pin limit' do
      cited = Array.new(30) { |n| ["Unit#{n}", 'model'] }
      expect(handoff({}, cited: cited).investigation['pin'].size).to eq(WoodsMap::TrailBoard::MAX_PINS)
    end
  end

  describe 'pin' do
    let(:board) do
      { 'page' => 'trail', 'entry' => 'NotifySubscribersJob#perform', 'pins' => ['model:Post'], 'gen' => 5,
        'hops' => 3 }
    end

    it 'adds the cited units the board lacks to the board the question was asked on' do
      expect(handoff(board).pin).to eq('entry' => 'NotifySubscribersJob#perform',
                                       'pin' => %w[model:Post job:NotifySubscribersJob], 'gen' => 5, 'hops' => 3)
    end

    it 'adds to the board the page shows now, so a board that has them offers no pin' do
      shown = board.merge('pins' => %w[model:Post job:NotifySubscribersJob])
      expect(described_class.new({ 'context' => board }, cited: [%w[Post model], %w[NotifySubscribersJob job]],
                                                         generation: 7, board: shown).pin).to be_nil
    end

    it 'is offered only on a Trail board, and only when it adds a unit' do
      expect(handoff({ 'type' => 'model', 'identifier' => 'Post' }).pin).to be_nil
      expect(handoff(board, cited: [%w[Post model]]).pin).to be_nil
    end
  end

  it 'turns both into paths' do
    answer = Struct.new(:cited).new([%w[Post model]])
    links = described_class.links({ 'context' => { 'page' => 'trail', 'pins' => ['job:X'] } }, answer: answer,
                                                                                               generation: 2) do |query|
      "/woods/trail?#{query.to_query}"
    end
    expect(links.keys).to eq(%w[pin investigation])
    expect(links['pin']).to include('pin%5B%5D=job%3AX').and include('pin%5B%5D=model%3APost')
  end
end
