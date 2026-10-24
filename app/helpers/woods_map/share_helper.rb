# frozen_string_literal: true

module WoodsMap
  # Absolute links the map hands out, and a diagram as a pull-request comment
  # (D-25, woods-map#76). Every absolute link starts at {#public_base_url}.
  module ShareHelper
    # @return [String] `config.public_url`, else the request's origin
    def public_base_url
      WoodsMap::PublicUrl.base(request)
    end

    # @param path [String] an engine path, such as a `.mmd` route's
    # @return [String] the absolute URL reviewers can open
    def public_url_for(path)
      "#{public_base_url}#{path}"
    end

    # The comment for one diagram panel: its text, the page's focus URL, the
    # generation this request reads and, when the panel has one, its `.mmd` URL.
    #
    # @param text [String] the Mermaid text the panel draws
    # @param name [String] what the diagram shows
    # @param url [String, nil] the panel's `.mmd` path
    # @return [WoodsMap::PrComment::Comment]
    def pr_comment(text, name:, url: nil)
      WoodsMap::PrComment.build(text, name: name, focus_url: focus_url,
                                      generation: current_repository&.generation_number,
                                      mmd_url: url && public_url_for(url))
    end
  end
end
