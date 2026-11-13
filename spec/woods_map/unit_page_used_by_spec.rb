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

  # One edge per unit, except ArchiveJob, which reaches the page five times.
  let(:repeated_edges) do
    [%w[Author model], %w[Comment model], %w[Reply model], %w[Tag model],
     %w[AuthorsController controller], %w[CommentsController controller], %w[TagsController controller],
     %w[Publisher service], %w[Search service], %w[Tagger service],
     %w[DigestMailer mailer], %w[ReplyMailer mailer]] + ([%w[ArchiveJob job]] * 5)
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
    expect(linked(tile([%w[A model], %w[A model], %w[B job]]))).to contain_exactly('A', 'B')
  end

  it 'ranks a type with more units above a type with more edges but fewer units' do
    rows = tile([%w[A model], %w[B model], %w[C model]] + ([%w[D job], %w[E job]] * 3))[:rows]
    expect(rows.map(&:first)).to eq(%w[models jobs])
  end

  it 'decides which types keep a row by their units, not their edges' do
    shown = tile(repeated_edges)
    expect(shown[:rows].map(&:first)).to eq(%w[models controllers services other])
    expect(shown[:rows].last.last[:links])
      .to eq([%w[DigestMailer mailer], %w[ReplyMailer mailer], %w[ArchiveJob job]])
  end

  it 'ranks by units whatever order the edges were published in' do
    expect(tile(repeated_edges.reverse)[:rows].map(&:first)).to eq(tile(repeated_edges)[:rows].map(&:first))
    expect(tile(repeated_edges.reverse)[:rows].map { |_, v| v[:links].sort })
      .to eq(tile(repeated_edges)[:rows].map { |_, v| v[:links].sort })
  end
end
