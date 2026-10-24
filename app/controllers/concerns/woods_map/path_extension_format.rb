# frozen_string_literal: true

module WoodsMap
  # Identifiers and file paths keep their extensions (config/database.yml,
  # locales/en.yml, app/javascript/x.js) and their routes declare
  # `format: false`, but without an Accept header Rails still takes the format
  # from the path's extension and looks for a YAML or JS template, a 500. A
  # route that names no format answers HTML; a request with an Accept header is
  # negotiated as before.
  module PathExtensionFormat
    extend ActiveSupport::Concern

    included do
      before_action :ignore_path_extension_format
    end

    private

    # @return [void]
    def ignore_path_extension_format
      return if request.path_parameters.key?(:format) || request.get_header('HTTP_ACCEPT').present?
      return if File.extname(request.path).empty?

      request.format = :html
    end
  end
end
