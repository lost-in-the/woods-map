# frozen_string_literal: true

RSpec.describe WoodsMap::UnitPage do
  def tile(edges)
    reverse = edges.map { |source, type| { 'source' => source, 'source_type' => type, 'via' => 'code_reference' } }
    repository = instance_double(WoodsMap::Repository, graph: { 'reverse_via' => { 'Post' => reverse } })
    unit = { 'identifier' => 'Post', 'type' => 'service', 'metadata' => {} }
    described_class.new(repository, unit).tiles.find { |t| t[:eyebrow].start_with?('Used by') }
  end

  def linked(tile)
    tile[:rows].flat_map { |_, value| value[:links].map(&:first) }
  end

  # The Rails 6.0 testbed's Post: two types of four, three types of one, and a document.
  let(:post_edges) do
    [%w[AddBlogColumnsToPosts migration], %w[CreateComments migration], %w[CreatePosts migration],
     %w[CreateTagsAndTaggings migration], %w[Comment model], %w[Tag model], %w[Tagging model], %w[User model],
     %w[NotifySubscribersJob job], %w[PostsController controller], %w[README.md doc], %w[db/seeds.rb configuration]]
  end

  it 'gives each type a row when they fit' do
    rows = tile([%w[A model], %w[B model], %w[C job], %w[D controller], %w[E service]])[:rows]
    expect(rows.map(&:first)).to eq(%w[models controllers jobs services])
  end

  it 'collects the types beyond the row limit under "other" instead of dropping them' do
    shown = tile(post_edges)
    expect(shown[:rows].map(&:first)).to eq(%w[models migrations other documentation])
    expect(shown[:rows][2].last[:links])
      .to eq([%w[PostsController controller], %w[NotifySubscribersJob job], %w[db/seeds.rb configuration]])
  end

  it 'links every dependent the eyebrow counts' do
    shown = tile(post_edges)
    expect(shown[:eyebrow]).to eq('Used by 11, 1 documentation')
    expect(linked(shown)).to match_array(post_edges.map(&:first))
  end

  it 'draws the same rows whatever order the edges were published in' do
    expect(tile(post_edges.reverse)[:rows].map(&:first)).to eq(tile(post_edges)[:rows].map(&:first))
    expect(linked(tile(post_edges.reverse))).to match_array(linked(tile(post_edges)))
  end

  it 'keeps four code rows when there is no documentation' do
    rows = tile(post_edges.reject { |_, type| type == 'doc' })[:rows]
    expect(rows.map(&:first)).to eq(%w[models migrations controllers other])
  end

  it 'repeats no unit that reaches the page by two edges' do
    expect(linked(tile([%w[A model], %w[A model], %w[B job]]))).to match_array(%w[A B])
  end

  it 'ranks a type by the units its row shows, not by the edges that reach the page' do
    edges = [%w[A model], %w[A model], %w[A model], %w[B model], %w[B model], %w[B model],
             %w[C job], %w[D job], %w[E job]]
    shown = tile(edges)
    expect(shown[:rows].map(&:first)).to eq(%w[jobs models])
    expect(shown[:rows].map { |_, value| value[:links].size }).to eq([3, 2])
  end

  it 'decides which types keep a row by units, so one unit reached many times goes to "other"' do
    edges = Array.new(5) { %w[A model] } +
            [%w[C1 controller], %w[C2 controller], %w[J1 job], %w[J2 job], %w[M1 mailer], %w[M2 mailer],
             %w[S1 service]]
    shown = tile(edges)
    expect(shown[:rows].map(&:first)).to eq(%w[controllers jobs mailers other])
    expect(shown[:rows].last.last[:links]).to eq([%w[A model], %w[S1 service]])
    expect(tile(edges.reverse)[:rows].map(&:first)).to eq(shown[:rows].map(&:first))
  end
end
