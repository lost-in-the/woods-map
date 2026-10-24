# frozen_string_literal: true

module WoodsMap
  # Pages whose path ends in an extension Rails knows as a format.
  module PathExtension
    extend ActiveSupport::Concern

    included do
      prepend_before_action :html_despite_path_extension
    end

    private

    # Unit identifiers and indexed file paths keep their extension in the
    # path (those routes take no format), yet Rails still reads a format from
    # the extension when a browser sends its catch-all Accept header: a unit
    # or file page for `config/cable.yml` would render as YAML (a missing
    # template, 500) and one for `app/javascript/application.js` as a page
    # without the layout. Every such page is HTML.
    def html_despite_path_extension
      return if params.key?(:format) || mermaid_request?

      extension = File.extname(request.path).delete_prefix('.')
      return if extension.empty?

      type = Mime::Type.lookup_by_extension(extension)
      request.format = :html if type && request.format == type
    end
  end
end
