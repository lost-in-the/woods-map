# frozen_string_literal: true

RSpec.describe WoodsMap::UnitPage do
  def tile(edges)
    dependencies = edges.map { |target, type, via| { 'target' => target, 'type' => type, 'via' => via } }
    repository = instance_double(WoodsMap::Repository, graph: { 'reverse_via' => {} })
    unit = { 'identifier' => 'Post', 'type' => 'model', 'metadata' => {}, 'dependencies' => dependencies }
    described_class.new(repository, unit).tiles.find { |t| t[:eyebrow].start_with?('Depends on') }
  end

  def linked(tile)
    tile[:rows].flat_map { |_, value| value[:links].map(&:first) }
  end

  # Seven relationships: references three, render two, and five of one each.
  let(:edges) do
    [%w[User model belongs_to], %w[Comment model has_many], %w[Taggable concern include],
     %w[NotifySubscribersJob job job_enqueue], %w[posts/_post view_template render],
     %w[posts/show view_template view_render], %w[Tag model code_reference], %w[Tagging model code_reference],
     %w[PostPolicy service code_reference], %w[PostsController controller route_dispatch],
     %w[PostMailer mailer mailer_call]]
  end

  # Six relationships: four of two units each, and two of one unit, one of them reached by three edges.
  let(:repeated_edges) do
    [%w[Author model belongs_to], %w[Comment model has_many], %w[Reply model has_many],
     %w[posts/_post view_template render], %w[posts/show view_template view_render],
     %w[Tag model code_reference], %w[Tagging model code_reference],
     %w[DigestMailer mailer mailer_call], %w[ReplyMailer mailer mailer_call]] +
      ([%w[ArchiveJob job job_enqueue]] * 3)
  end

  # Six relationships: references three, render two, and four of one each.
  let(:shared_edges) do
    [%w[Tag model code_reference], %w[Tagging model code_reference], %w[PostsController controller code_reference],
     %w[posts/_post view_template render], %w[posts/show view_template view_render],
     %w[Author model belongs_to], %w[Comment model has_many], %w[Taggable concern include],
     %w[PostsController controller route_dispatch]]
  end

  it 'gives each relationship a row when they fit, associations first whatever their size' do
    rows = tile([%w[User model belongs_to], %w[Tag model code_reference], %w[Tagging model code_reference],
                 %w[Comment model has_many]])[:rows]
    expect(rows.map(&:first)).to eq(%w[belongs_to has_many references])
  end

  it 'collects the relationships beyond the row limit under "other" instead of dropping them' do
    shown = tile(edges)
    expect(shown[:rows].map(&:first)).to eq(%w[belongs_to has_many render references other])
    expect(shown[:rows].last.last[:links])
      .to eq([%w[Taggable concern], %w[NotifySubscribersJob job], %w[PostsController controller],
              %w[PostMailer mailer]])
  end

  it 'links every dependency the eyebrow counts' do
    shown = tile(edges)
    expect(shown[:eyebrow]).to eq('Depends on 11')
    expect(linked(shown)).to match_array(edges.map(&:first))
  end

  it 'draws the same rows whatever order the edges were published in' do
    expect(tile(edges.reverse)[:rows].map(&:first)).to eq(tile(edges)[:rows].map(&:first))
    expect(tile(edges.reverse)[:rows].map { |_, v| v[:links].sort })
      .to eq(tile(edges)[:rows].map { |_, v| v[:links].sort })
  end

  it 'keeps five rows without "other" when exactly five relationships fit' do
    rows = tile(edges.first(5))[:rows]
    expect(rows.map(&:first)).to eq(%w[belongs_to has_many include enqueue render])
  end

  it 'repeats no target that the unit reaches by two edges in one row' do
    shown = tile([%w[Tag model code_reference], %w[Tag model code_reference], %w[User model belongs_to]])
    expect(linked(shown)).to eq(%w[User Tag])
  end

  it 'repeats no target in "other" when two overflowing relationships reach it' do
    overflow = edges + [%w[PostMailer mailer link_to]]
    other = tile(overflow)[:rows].last.last[:links]
    expect(other.count(%w[PostMailer mailer])).to eq(1)
  end

  it 'decides which relationships keep a row by their units, not their edges' do
    shown = tile(repeated_edges)
    expect(shown[:rows].map(&:first)).to eq(%w[has_many render references mail other])
    expect(shown[:rows].last.last[:links]).to eq([%w[Author model], %w[ArchiveJob job]])
  end

  it 'keeps the units ranking whatever order the edges were published in' do
    expect(tile(repeated_edges.reverse)[:rows].map(&:first)).to eq(tile(repeated_edges)[:rows].map(&:first))
    expect(tile(repeated_edges.reverse)[:rows].map { |_, v| v[:links].sort })
      .to eq(tile(repeated_edges)[:rows].map { |_, v| v[:links].sort })
  end

  it 'does not repeat in "other" a target that a named row links' do
    shown = tile(shared_edges)
    expect(shown[:rows].map(&:first)).to eq(%w[belongs_to has_many render references other])
    expect(shown[:rows].last.last[:links]).to eq([%w[Taggable concern]])
  end

  it 'omits "other" when every target it would hold is linked by a named row' do
    shown = tile(shared_edges + [%w[Taggable concern code_reference]])
    expect(shown[:rows].map(&:first)).to eq(%w[belongs_to has_many render references])
    expect(linked(shown)).to match_array(shared_edges.map(&:first).uniq)
  end

  it 'links a target under each named relationship that reaches it' do
    rows = tile([%w[Author model belongs_to], %w[Author model code_reference], %w[Tag model code_reference]])[:rows]
    expect(rows.to_h.transform_values { |v| v[:links] })
      .to eq('belongs_to' => [%w[Author model]], 'references' => [%w[Author model], %w[Tag model]])
  end
end
