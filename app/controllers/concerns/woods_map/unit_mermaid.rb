# frozen_string_literal: true

module WoodsMap
  # The unit tabs' `.mmd` answers (D-25): the text of the tab's diagram for
  # the same parameters as the page, through {MermaidText}.
  module UnitMermaid
    extend ActiveSupport::Concern

    private

    # The lifecycle's text for the requested view; a state_machine unit's
    # lifecycle is its state diagram.
    def render_lifecycle_mermaid
      if @page.type == 'state_machine'
        machine = WoodsMap::StateMachineView.new(@unit)
        return render_tab_mermaid(machine.mermaid, 'state', refusal: machine.refusal)
      end

      render_tab_mermaid(@lifecycle.diagram(@view, @event), "lifecycle #{@event} #{@view}",
                         refusal: @lifecycle.refusal(@event, view: @view))
    end

    def render_graph_mermaid
      render_tab_mermaid(@neighbourhood.mermaid, "neighbourhood depth #{@neighbourhood.depth}",
                         refusal: @neighbourhood.refusal)
    end

    # A tab's Mermaid text; a refused one names the page that lists everything.
    def render_tab_mermaid(text, what, refusal: nil)
      page = request.base_url + request.path.delete_suffix('.mmd')
      page += "?#{request.query_string}" if request.query_string.present?
      render_mermaid(text, name: "#{@page.identifier} #{what}", refusal: refusal, page: page)
    end
  end
end
