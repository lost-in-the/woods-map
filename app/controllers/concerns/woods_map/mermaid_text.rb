# frozen_string_literal: true

module WoodsMap
  # The Mermaid text of a page's diagram as `text/plain` (D-25): the `.mmd`
  # routes answer with the same text the panel draws, so an agent never
  # scrapes HTML. The routes set the `mmd` path parameter; a query string
  # cannot. Every answer, refusals and errors included, is plain text: a
  # budget refusal (R-4) is 422 with the reason, never a truncated diagram.
  #
  # A `.md` route (the `md` path parameter, beside `mmd`) answers with the
  # same text as a GitHub pull-request comment (woods-map#76): a fenced
  # ```` ```mermaid ```` block and one line linking the page and its `.mmd`
  # URL. It follows every `.mmd` rule, and a comment longer than GitHub holds
  # is 422 with the reason too.
  module MermaidText
    extend ActiveSupport::Concern

    # The suffixes the text routes add to a page's path.
    SUFFIX = /\.mm?d\z/

    private

    # @return [Boolean] whether this request came in on a `.mmd` or `.md` route
    def mermaid_request?
      request.path_parameters[:mmd] == '1'
    end

    # @return [Boolean] whether this request came in on a `.md` route
    def pr_comment_request?
      mermaid_request? && request.path_parameters[:md] == '1'
    end

    # @param text [String] the Mermaid text
    # @param name [String] what the diagram shows, for the file name
    # @param refusal [String, nil] why it is not drawn (R-4), answered as 422
    # @param page [String, nil] the page that lists what a refused diagram would draw
    def render_mermaid(text, name:, refusal: nil, page: nil)
      generation_header
      if refusal
        listed = " The page lists every one: #{page}" if page
        return render_text(:unprocessable_entity, "#{refusal}. No diagram is drawn above the budget.#{listed}")
      end
      return render_pr_comment(text, name) if pr_comment_request?

      response.headers['Content-Disposition'] =
        ActionDispatch::Http::ContentDisposition.format(disposition: 'inline', filename: MermaidExport.filename(name))
      render plain: text.end_with?("\n") ? text : "#{text}\n", content_type: 'text/plain'
    end

    # @param text [String] the Mermaid text
    # @param name [String] what the diagram shows
    def render_pr_comment(text, name)
      comment = PrComment.build(text, name: name, focus_url: mermaid_page_url,
                                      generation: @repository&.generation_number, mmd_url: mermaid_text_url)
      return render_text(:unprocessable_entity, comment.refusal) unless comment.body

      response.headers['Content-Disposition'] = ActionDispatch::Http::ContentDisposition.format(
        disposition: 'inline', filename: MermaidExport.filename(name, extension: 'md')
      )
      render plain: comment.body, content_type: 'text/markdown'
    end

    # The absolute, token-free URL of the page a text route belongs to: its
    # path without the `.mmd` or `.md` suffix and its query, at `config.public_url`.
    #
    # @return [String]
    def mermaid_page_url
      public_text_url(mermaid_page_path)
    end

    # @return [String] the absolute `.mmd` URL of this request's diagram
    def mermaid_text_url
      public_text_url("#{raw_request_path.sub(SUFFIX, '')}.mmd")
    end

    # @return [String] the page's path; the Landscape maps its diagrams to their tabs
    def mermaid_page_path
      raw_request_path.sub(SUFFIX, '')
    end

    def public_text_url(path)
      query = request.query_parameters.except('token')
      "#{PublicUrl.base(request)}#{path}#{"?#{query.to_query}" if query.any?}"
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
