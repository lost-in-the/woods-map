# frozen_string_literal: true

module WoodsMap
  # A Passage or Lifecycle URL whose ?action_name= names an action the unit
  # does not have answers 404 with the actions it has, never another action's
  # page (a stale or mistyped link would otherwise look like an answer).
  module UnknownAction
    private

    # Whether ?action_name= names an action the unit does not have. Without
    # it the tab shows the first action; with a wrong one it must not
    # silently show another (a stale or mistyped link).
    def unknown_action?(actions)
      requested = params[:action_name].to_s
      !requested.empty? && actions.exclude?(requested)
    end

    # 404: the frame, what was asked for and the actions the unit has, each a
    # link; plain text on the `.mmd` route.
    def render_unknown_action(tab, actions)
      @requested_action = params[:action_name].to_s
      @actions = actions
      @tab = tab
      message = "#{@page.identifier} has no action #{@requested_action}" \
                "#{actions.any? ? "; its actions: #{actions.join(', ')}" : '; it lists no actions'}."
      return render_text(:not_found, message) if mermaid_request?

      render :unknown_action, status: :not_found
    end
  end
end
