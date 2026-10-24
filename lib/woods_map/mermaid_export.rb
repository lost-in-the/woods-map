# frozen_string_literal: true

module WoodsMap
  # The copy and download of a diagram's Mermaid text (mermaid-diagram-types.md,
  # constraint 3): the same text the panel draws, saved as `.mmd`. Structurizr
  # DSL and LikeC4 exports need container attribution (W-9) and are not made.
  module MermaidExport
    # Diagram keywords newer than the Mermaid that GitHub renders Markdown
    # with: Mermaid 11.13 and later. Copied text of these may not draw in an
    # issue or a pull request. Every keyword the map generates today is older,
    # except `swimlane-beta`.
    NEWER_THAN_GITHUB = %w[swimlane-beta usecase-beta agentflow-beta eventmodeling venn-beta ishikawa-beta
                           wardley-beta cynefin-beta treeView-beta].freeze
    # Mermaid text larger than this stays at its .mmd URL rather than in the
    # page: the copy tool fetches it, and a panel that does not draw it links
    # to it. A large neighbourhood or blast radius otherwise carries
    # megabytes of text, several times over, on every view.
    INLINE_BYTES = 64 * 1024

    module_function

    # @param name [String] what the diagram shows, such as "Post lifecycle create"
    # @return [String] a safe file name ending in .mmd
    def filename(name)
      base = name.to_s.gsub('::', '-').parameterize.first(80).delete_suffix('-')
      "#{base.presence || 'diagram'}.mmd"
    end

    # @param text [String] Mermaid text
    # @param url [String, nil] the text's .mmd route
    # @return [Boolean] whether the page links to the text instead of carrying it
    def linked?(text, url)
      url.present? && text.to_s.bytesize > INLINE_BYTES
    end

    # @param text [String] Mermaid text
    # @return [Boolean] whether GitHub's renderer may not know the diagram type
    def newer_than_github?(text)
      NEWER_THAN_GITHUB.include?(text.to_s.lstrip.split(/\s/, 2).first.to_s)
    end
  end
end
