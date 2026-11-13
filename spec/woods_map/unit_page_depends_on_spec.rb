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

  it 'decides which relationships keep a row by distinct targets, not by edges' do
    edges = [%w[User model belongs_to]] + Array.new(5) { %w[Tag model code_reference] } +
            [%w[posts/_a view_template render], %w[posts/_b view_template render], %w[AJob job job_enqueue],
             %w[BJob job job_enqueue], %w[AController controller route_dispatch],
             %w[BController controller route_dispatch], %w[AMailer mailer mailer_call],
             %w[BMailer mailer mailer_call]]
    shown = tile(edges)
    expect(shown[:rows].map(&:first)).to eq(%w[enqueue render route mail other])
    expect(shown[:rows].last.last[:links]).to eq([%w[User model], %w[Tag model]])
    expect(tile(edges.reverse)[:rows].map(&:first)).to eq(shown[:rows].map(&:first))
  end

  it 'links a target under each named relationship that reaches it' do
    shown = tile([%w[User model belongs_to], %w[User model code_reference], %w[Tag model code_reference]])
    expect(shown[:rows]).to eq([['belongs_to', { links: [%w[User model]] }],
                                ['references', { links: [%w[User model], %w[Tag model]] }]])
    expect(shown[:eyebrow]).to eq('Depends on 2')
  end

  it 'repeats in "other" no target a named row already links' do
    shown = tile(edges + [%w[Tag model link_to]])
    expect(shown[:rows].map(&:first)).to eq(%w[belongs_to has_many render references other])
    expect(shown[:rows].last.last[:links])
      .to eq([%w[Taggable concern], %w[NotifySubscribersJob job], %w[PostsController controller],
              %w[PostMailer mailer]])
  end

  it 'omits "other" when every target it would hold is linked in a named row' do
    edges = [%w[posts/_a view_template render], %w[posts/_b view_template render], %w[Tag model code_reference],
             %w[Tagging model code_reference], %w[AJob job job_enqueue], %w[BJob job job_enqueue],
             %w[AController controller route_dispatch], %w[BController controller route_dispatch],
             %w[Tag model link_to], %w[AController controller test_coverage]]
    shown = tile(edges)
    expect(shown[:rows].map(&:first)).to eq(%w[enqueue render references route])
    expect(linked(shown)).to match_array(edges.map(&:first).uniq)
  end
end
