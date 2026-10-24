# frozen_string_literal: true

module WoodsMap
  # The History tab of a unit page (M4, B6-History): the commit table's
  # view of the unit, its `.mmd` exports, and the unit's record in Woods'
  # report between two retained generations (B-14).
  module UnitHistory
    extend ActiveSupport::Concern
    include AuthorFilter

    included do
      # A unit diff runs Woods' report over two retained generations: the impact budget.
      woods_map_rate_limit :impact, only: :history, if: -> { params[:from].present? || params[:to].present? }
    end

    # The History tab (B6-History) from the commit table; ?from=&to= adds the
    # unit's record in Woods' report between two retained generations (B-14).
    def history
      with_unit do
        @history = WoodsMap::HistoryView.new(@repository, @unit, range: params[:range], week: params[:week],
                                                                 all: params[:all] == '1', by: params[:by],
                                                                 gen: params[:gen], author: author_param,
                                                                 span: params[:span])
        next render_history_mermaid if mermaid_request?

        @diff = WoodsMap::UnitDiff.for(@repository, @unit, from: params[:from], to: params[:to])
        render :history
      end
    end

    private

    # The History tab's export: the commits as a timeline, or commits per
    # bar of the strip as an XY chart (?view=xychart).
    def render_history_mermaid
      view = WoodsMap::HistoryMermaid::VIEWS.include?(params[:view]) ? params[:view] : 'timeline'
      text = @history.mermaid(view)
      return render_text(:not_found, "No commits to draw for #{@page.identifier}.") unless text

      render_tab_mermaid(text, "history #{view}")
    end
  end
end
