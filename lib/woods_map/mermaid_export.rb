# frozen_string_literal: true

module WoodsMap
  # The copy and download of a diagram's Mermaid text (mermaid-diagram-types.md,
  # constraint 3): the same text the panel draws, saved as `.mmd`. Structurizr
  # DSL and LikeC4 exports need container attribution (W-9) and are not made.
  module MermaidExport
    # The Mermaid GitHub renders Markdown with (woods-map#76). GitHub does not
    # publish it; its docs say to check with an `info` diagram, and the latest
    # such check on record (GitHub Community discussion #70672, 20 August 2026)
    # read 11.16.1. `spec/diagrams/github_mermaid_spec.rb` parses every text the
    # map generates with this exact build, vendored for the spec only. Update
    # both together after the next `info` check (spec/vendor/github_mermaid).
    GITHUB_MERMAID_VERSION = '11.16.1'

    # Diagram keywords that {GITHUB_MERMAID_VERSION} does not know (Mermaid 12
    # added them). Copied text of these would not draw in an issue or a pull
    # request. The map generates none of them today; the GitHub Mermaid spec
    # checks that the vendored build still rejects each one.
    NEWER_THAN_GITHUB = %w[usecase-beta agentflow-beta].freeze
    # Mermaid text larger than this is not carried in the page. A drawn or
    # unbudgeted diagram's copy tool fetches it from its .mmd route; a
    # diagram over its drawing budget, whose .mmd answers 422, offers no copy
    # and its panel says why. A hub's neighbourhood or blast radius otherwise
    # carries megabytes of text, several times over, on every view.
    INLINE_BYTES = 64 * 1024

    module_function

    # @param name [String] what the diagram shows, such as "Post lifecycle create"
    # @param extension [String] `mmd` for the text, `md` for the pull-request comment
    # @return [String] a safe file name ending in the extension
    def filename(name, extension: 'mmd')
      base = name.to_s.gsub('::', '-').parameterize.first(80).delete_suffix('-')
      "#{base.presence || 'diagram'}.#{extension}"
    end

    # @param text [String] Mermaid text
    # @return [Boolean] whether the text is too large to carry in a page
    def oversized?(text)
      text.to_s.bytesize > INLINE_BYTES
    end

    # @param text [String] Mermaid text
    # @return [Boolean] whether GitHub's renderer may not know the diagram type
    def newer_than_github?(text)
      NEWER_THAN_GITHUB.include?(text.to_s.lstrip.split(/\s/, 2).first.to_s)
    end
  end
end
