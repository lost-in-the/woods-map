# frozen_string_literal: true

module WoodsMap
  # A diagram as text that pastes into a GitHub pull-request comment and
  # draws there (D-25 as amended, woods-map#76): the Mermaid text in a fenced
  # ```` ```mermaid ```` block, then one line linking the view it came from
  # and its `.mmd` text, naming the generation the text was drawn from.
  #
  # The map never posts the comment, and this is not a report: no rows,
  # findings or facts beyond the diagram and where it came from. A text
  # longer than a GitHub comment holds is refused with the reason, never cut,
  # because a cut fence pastes as a broken diagram.
  module PrComment
    # GitHub's limit on a comment body, in characters.
    LIMIT = 65_536

    # One comment: the body to paste, or why there is none, and its length in characters.
    Comment = Struct.new(:body, :refusal, :length, keyword_init: true) do
      # @return [String, nil] the refusal in a few words, for a tool band
      def short_refusal
        return nil unless refusal

        "too long for a PR comment (#{PrComment.delimited(length)} of #{PrComment.delimited(LIMIT)} characters)"
      end
    end

    # Characters a link label escapes so the label stays plain text.
    LABEL_SPECIALS = /[\\`*_\[\]<>&~!|]/
    # Characters a link destination percent-encodes so `[label](url)` holds.
    URL_SPECIALS = /[\s()<>\[\]]/

    module_function

    # @param text [String] the Mermaid text, as the panel draws it
    # @param name [String] what the diagram shows, such as "User lifecycle update sequence"
    # @param focus_url [String] the absolute, token-free URL of the view it came from
    # @param generation [Integer, nil] the generation the text was drawn from
    # @param mmd_url [String, nil] the absolute URL of the same text as `.mmd`
    # @return [Comment]
    def build(text, name:, focus_url:, generation:, mmd_url: nil)
      body = "#{fenced(text)}\n#{link_line(name, focus_url, generation, mmd_url)}\n"
      return Comment.new(body: body, refusal: nil, length: body.length) if body.length <= LIMIT

      Comment.new(body: nil, refusal: too_long(body.length), length: body.length)
    end

    # @param length [Integer] characters of the comment
    # @return [String] why it is not offered
    def too_long(length)
      "Too long for a GitHub comment: #{delimited(length)} characters, over its limit of #{delimited(LIMIT)}. " \
        'Share the .mmd URL instead.'
    end

    # A fence longer than any run of backticks in the text, so the text
    # cannot close it early (CommonMark).
    def fenced(text)
      source = text.to_s.chomp
      fence = '`' * [3, source.scan(/`+/).map(&:length).max.to_i + 1].max
      "#{fence}mermaid\n#{source}\n#{fence}"
    end

    def link_line(name, focus_url, generation, mmd_url)
      label = ['Woods Map', name.to_s.squish, ("gen #{generation}" if generation)].compact.join(', ')
      line = "[#{escape_label(label)}](#{escape_url(focus_url)})"
      mmd_url ? "#{line} · [Mermaid text](#{escape_url(mmd_url)})" : line
    end

    def escape_label(label)
      label.gsub(LABEL_SPECIALS) { |character| "\\#{character}" }
    end

    def escape_url(url)
      url.to_s.gsub(URL_SPECIALS) { |character| format('%%%02X', character.ord) }
    end

    # @param number [Integer]
    # @return [String] with thousands separators, as GitHub writes its limit
    def delimited(number)
      number.to_s.reverse.scan(/\d{1,3}/).join(',').reverse
    end
  end
end
