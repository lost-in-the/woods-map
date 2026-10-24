# frozen_string_literal: true

module WoodsMap
  # The Mermaid text of a page's diagram as `text/plain` (D-25): the `.mmd`
  # routes answer with the same text the panel draws, so an agent never
  # scrapes HTML. The routes set the `mmd` path parameter; a query string
  # cannot. Every answer, refusals and errors included, is plain text: a
  # budget refusal (R-4) is 422 with the reason, never a truncated diagram.
  module MermaidText
    extend ActiveSupport::Concern

    private

    # @return [Boolean] whether this request came in on a `.mmd` route
    def mermaid_request?
      request.path_parameters[:mmd] == '1'
    end

    # @param text [String] the Mermaid text
    # @param name [String] what the diagram shows, for the file name
    # @param refusal [String, nil] why it is not drawn (R-4), answered as 422
    # @param page [String, nil] the page that lists what a refused diagram would draw
    def render_mermaid(text, name:, refusal: nil, page: nil)
      generation_header
      if refusal
        return render_text(:unprocessable_entity,
                           "#{refusal}. No diagram is drawn above the budget.#{" The page lists every one: #{page}" if page}")
      end

      response.headers['Content-Disposition'] =
        ActionDispatch::Http::ContentDisposition.format(disposition: 'inline', filename: MermaidExport.filename(name))
      render plain: text.end_with?("\n") ? text : "#{text}\n", content_type: 'text/plain'
    end

    # @param status [Symbol]
    # @param message [String]
    def render_text(status, message)
      generation_header
      render plain: "#{message}\n", status: status, content_type: 'text/plain'
    end

    def generation_header
      response.headers['X-Woods-Generation'] = @repository.generation_number.to_s if @repository
    end
  end
end
