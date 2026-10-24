# frozen_string_literal: true

require 'cgi'

module WoodsMap
  module Guide
    # Renders an answer's Markdown to HTML the map controls (design study,
    # section 11): raw HTML is stripped, Markdown links lose their URL, and
    # the only links are to identifiers the pinned generation knows. A name
    # the model invents stays plain text, so the guide cannot make a link.
    #
    # The subset is the one the agent is asked to write: paragraphs, ordered
    # and unordered lists, headings (shown bold), fenced code, `code`,
    # **bold** and *emphasis*.
    class Answer
      CONSTANT = /(?<![\w:#.@])[A-Z][A-Za-z0-9_]*(?:::[A-Z][A-Za-z0-9_]*)*(?:#[a-z_][a-zA-Z0-9_]*[?!]?)?/
      TAG = %r{</?[A-Za-z][^>]*>}
      FENCE = /\A\s*```/
      LIST_ITEM = /\A\s*(?:([-*+])|(\d+)[.)])\s+(.*)\z/
      HEADING = /\A\s*\#{1,6}\s+(.*)\z/

      # @param markdown [String]
      # @param identifiers [Hash{String => String}] identifier => unit type
      # @param link [#call] (identifier, type) => href
      def initialize(markdown, identifiers:, link:)
        @markdown = markdown.to_s
        @identifiers = identifiers
        @link = link
      end

      # @return [String] HTML, safe to emit as is
      def to_html
        blocks.join
      end

      private

      def blocks
        html = []
        lines = @markdown.gsub("\r\n", "\n").split("\n", -1)
        until lines.empty?
          line = lines.first
          if line.strip.empty? then lines.shift
          elsif line.match?(FENCE) then html << fenced(lines)
          elsif line.match?(LIST_ITEM) then html << list(lines)
          else html << paragraph(lines)
          end
        end
        html
      end

      def fenced(lines)
        lines.shift
        body = []
        body << lines.shift until lines.empty? || lines.first.match?(FENCE)
        lines.shift
        %(<pre class="cmd" tabindex="0">#{escape(body.join("\n"))}</pre>)
      end

      def list(lines)
        ordered = !LIST_ITEM.match(lines.first)[2].nil?
        items = []
        while lines.any? && (match = LIST_ITEM.match(lines.first)) && match[2].nil? != ordered
          lines.shift
          text = [match[3]]
          text << lines.shift.strip while lines.any? && continuation?(lines.first)
          items << "<li>#{inline(text.join(' '))}</li>"
        end
        tag = ordered ? 'ol' : 'ul'
        "<#{tag}>#{items.join}</#{tag}>"
      end

      def continuation?(line)
        !line.strip.empty? && line.start_with?('  ') && !line.match?(LIST_ITEM) && !line.match?(FENCE)
      end

      def paragraph(lines)
        if (heading = HEADING.match(lines.first))
          lines.shift
          return "<p><b>#{inline(heading[1])}</b></p>"
        end

        text = []
        text << lines.shift.strip while lines.any? && paragraph_line?(lines.first)
        "<p>#{inline(text.join(' '))}</p>"
      end

      def paragraph_line?(line)
        !line.strip.empty? && !line.match?(FENCE) && !line.match?(LIST_ITEM) && !line.match?(HEADING)
      end

      # Code spans first, so nothing inside them is formatted; then links,
      # strong and emphasis over the escaped text, then identifiers.
      def inline(text)
        text.split(/(`[^`]*`)/).map do |part|
          if part.start_with?('`') && part.end_with?('`') && part.size > 1
            code(part[1...-1])
          else
            prose(part)
          end
        end.join
      end

      def code(text)
        target = known(text.strip) || known(text.strip.split('#').first.to_s)
        inner = "<code>#{escape(text)}</code>"
        target ? anchor(target, inner) : inner
      end

      def prose(text)
        text = text.gsub(TAG, '').gsub(/!?\[([^\]]*)\]\([^)]*\)/, '\1')
        html = escape(text)
        html = html.gsub(/\*\*(?=\S)(.+?)(?<=\S)\*\*/, '<b>\1</b>')
        html = html.gsub(/(?<![*\w])\*(?=\S)(.+?)(?<=\S)\*(?![*\w])/, '<em>\1</em>')
        link_identifiers(html)
      end

      # Identifiers sit in text that is already escaped; constants carry no
      # character escaping changes, so matching the escaped text is exact.
      def link_identifiers(html)
        html.gsub(CONSTANT) do |name|
          target = known(name) || known(name.split('#').first)
          target ? anchor(target, name) : name
        end
      end

      def known(name)
        type = @identifiers[name]
        type ? [name, type] : nil
      end

      def anchor((identifier, type), inner)
        %(<a href="#{escape(@link.call(identifier, type))}">#{inner}</a>)
      end

      def escape(text)
        CGI.escapeHTML(text.to_s)
      end
    end
  end
end
