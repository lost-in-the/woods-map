# frozen_string_literal: true

module WoodsMap
  # One page of a long list (the units index, a graph's edges, an impact's
  # affected units): the rows a page renders, out of a total it still counts.
  # Pages are 1-based; a page past the end shows the last one.
  class ListPage
    # @return [Array] the rows on this page
    attr_reader :items
    # @return [Integer] this page, the page count, the rows per page and the total rows
    attr_reader :number, :pages, :per, :total

    # @param items [Array] every row, in order
    # @param param [Object] the requested page (`params[:page]`)
    # @param per [Integer] rows per page
    def initialize(items, param, per:)
      @total = items.size
      @per = per
      @pages = [(@total.to_f / per).ceil, 1].max
      @number = param.is_a?(String) && param.match?(/\A[1-9][0-9]{0,5}\z/) ? [param.to_i, @pages].min : 1
      @items = items.slice((@number - 1) * per, per) || []
    end

    # @return [Boolean] whether the list spans more than one page
    def paged?
      @pages > 1
    end

    # @return [Integer] 1-based position of the first row on this page
    def first_row
      @total.zero? ? 0 : ((@number - 1) * @per) + 1
    end

    # @return [Integer] 1-based position of the last row on this page
    def last_row
      first_row.zero? ? 0 : first_row + @items.size - 1
    end
  end
end
