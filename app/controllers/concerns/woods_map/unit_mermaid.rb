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

    # An entry's flow in the requested view (woods-map#91).
    def render_entry_lifecycle_mermaid
      lifecycle = @entry_lifecycle
      return render_text(:not_found, "#{@page.identifier} has no action to draw.") unless lifecycle.entry

      render_tab_mermaid(lifecycle.diagram(@view), "lifecycle #{lifecycle.action} #{@view}",
                         refusal: lifecycle.refusal(@view))
    end

    # The passage's sequence, or with ?view=dynamic its C4 dynamic view (B-23).
    def render_passage_mermaid
      return render_tab_mermaid(@passage.mermaid, "#{@passage.action} passage") unless params[:view] == 'dynamic'

      @dynamic = WoodsMap::DynamicView.new(@repository)
      return render_text(:not_found, 'This generation has no container attribution (W-9).') unless @dynamic.attributed?

      text = passage_dynamic
      render_tab_mermaid(text, "#{@passage.action} passage dynamic", refusal: WoodsMap::DynamicView.refusal(text))
    end

    # @return [String] the passage's C4 dynamic text, with its ladder model's chain when it has one
    def passage_dynamic
      steps = @ladder && @ladder_event ? @ladder.steps(@ladder_event) : []
      @dynamic.passage(@passage, @ladder && @ladder_model, steps, @ladder && @ladder_event)
    end

    def render_graph_mermaid
      render_tab_mermaid(@neighbourhood.mermaid, "neighbourhood depth #{@neighbourhood.depth}",
                         refusal: @neighbourhood.refusal)
    end

    # A tab's Mermaid text; a refused one names the page that lists everything.
    # The Schema tab's ER text, or its class diagram with `?view=class`.
    def render_schema_mermaid
      shown = params[:view] == 'class' ? @schema.class_diagram : @schema
      render_tab_mermaid(shown.mermaid, 'schema', refusal: shown.refusal)
    end

    def render_tab_mermaid(text, what, refusal: nil)
      page = request.base_url + raw_request_path.delete_suffix('.mmd')
      page += "?#{request.query_string}" if request.query_string.present?
      render_mermaid(text, name: "#{@page.identifier} #{what}", refusal: refusal, page: page)
    end
  end
end
