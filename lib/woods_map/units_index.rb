# frozen_string_literal: true

module WoodsMap
  # The units index: every typed identity of the generation, grouped by type.
  # The overview shows the first rows of each type with their exact counts;
  # `?type=` lists one type a page at a time, so no page carries every unit.
  class UnitsIndex
    # Rows each type shows on the overview; the type's own page lists the rest.
    PER_TYPE = 100
    # Rows on one page of a type's own listing.
    PER_PAGE = 500

    # @return [Hash{String => Integer}] type => units of that type
    attr_reader :type_counts
    # @return [String, nil] the one type listed, when ?type= names a present type
    attr_reader :type
    # @return [ListPage, nil] that type's page
    attr_reader :list

    # @param listing [Hash{String => Array<Hash>}] {Repository#unit_listing}
    # @param type [Object] the requested type
    # @param page [Object] the requested page
    def initialize(listing, type: nil, page: nil)
      @listing = listing
      @type_counts = listing.transform_values(&:size)
      @type = type if type.is_a?(String) && listing.key?(type)
      @list = ListPage.new(listing[@type], page, per: PER_PAGE) if @type
    end

    # @return [Integer] every unit of the generation
    def unit_count
      @type_counts.values.sum
    end

    # @return [Hash{String => Array<Hash>}] type => the rows this page shows
    def groups
      return { @type => @list.items } if @type

      @listing.transform_values { |units| units.first(PER_TYPE) }
    end
  end
end
