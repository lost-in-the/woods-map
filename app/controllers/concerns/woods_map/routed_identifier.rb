# frozen_string_literal: true

module WoodsMap
  # The unit identifier a unit route names, slash included, and the page
  # for a typed identifier the pinned generation does not hold.
  module RoutedIdentifier
    extend ActiveSupport::Concern

    private

    # The identifiers the route may name. Rails drops a trailing slash and
    # squeezes a doubled one before it matches a route, so an identifier that
    # ends in "/" (the root route, `GET /`) arrives without it; the raw path
    # keeps the slash (`…/GET%20/`, `…/GET%20//graph`), and then the slashed
    # identifier is tried first.
    #
    # @return [Array<String>]
    def routed_identifiers
      identifier = params[:identifier].to_s
      suffix = action_name == 'show' ? '' : "/#{action_name}#{'.mmd' if mermaid_request?}"
      path = raw_request_path
      slashed = path.end_with?("/#{suffix}") && !identifier.end_with?('/')
      slashed ? ["#{identifier}/", identifier] : [identifier]
    end

    def render_missing_unit
      @identifier = params[:identifier].to_s
      @type = params[:type].to_s
      return render_text(:not_found, "No #{@type.tr('_', ' ')} named #{@identifier}.") if mermaid_request?

      render 'woods_map/units/missing', status: :not_found
    end
  end
end
