# frozen_string_literal: true

module WoodsMap
  # The `?author=` the timelines are narrowed to (woods-map#92, design-study
  # scenario 2 step 4): the History tab, `/woods/history` and the graph's
  # timeline. The value is a commit author as git recorded it in the
  # generation's commit table, matched exactly; it is index data, so it may
  # travel in a focus URL.
  module AuthorFilter
    extend ActiveSupport::Concern

    # Longest `?author=` the timelines match: a git author name, never free text.
    AUTHOR_PARAM_LIMIT = 256

    private

    # @return [String, nil] one non-empty string within the limit; anything else is no filter
    def author_param
      value = params[:author]
      value if value.is_a?(String) && !value.empty? && value.length <= AUTHOR_PARAM_LIMIT
    end
  end
end
