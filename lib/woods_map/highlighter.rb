# frozen_string_literal: true

require 'rouge'
require 'erb'

module WoodsMap
  # Server-side syntax highlighting onto the token classes of the code view
  # (`.k .fn .var .str .const .op .cm`), one HTML string per line. Rouge does
  # the lexing; the token-to-class map is the only styling decision here.
  module Highlighter
    LEXERS = {
      'ruby' => Rouge::Lexers::Ruby,
      'erb' => Rouge::Lexers::ERB,
      'haml' => Rouge::Lexers::Haml,
      'slim' => Rouge::Lexers::Slim,
      'yaml' => Rouge::Lexers::YAML,
      'js' => Rouge::Lexers::Javascript,
      'sql' => Rouge::Lexers::SQL
    }.freeze

    # Rouge token qualname prefix => code-view class.
    CLASSES = [
      ['Comment', 'cm'], ['Keyword', 'k'], ['Name.Function', 'fn'], ['Name.Class', 'const'],
      ['Name.Constant', 'const'], ['Name.Namespace', 'const'], ['Name.Variable', 'var'],
      ['Name.Decorator', 'fn'], ['Name.Builtin', 'fn'], ['Literal.String', 'str'],
      ['Literal.Number', 'const'], ['Operator', 'op'], ['Punctuation', 'op']
    ].freeze

    EXTENSIONS = { '.erb' => 'erb', '.haml' => 'haml', '.slim' => 'slim', '.yml' => 'yaml', '.yaml' => 'yaml',
                   '.js' => 'js', '.sql' => 'sql' }.freeze

    module_function

    # @param source [String]
    # @param language [String] a key of {LEXERS}; unknown languages are escaped only
    # @param references [Hash{Integer => Array<WoodsMap::References::Link>}] validated row byte intervals
    # @param unit_path [#call, nil] request-context identifier, type => URL
    # @return [Array<String>] HTML for each line, in order
    def lines(source, language: 'ruby', references: {}, unit_path: nil)
      token_lines(source, language).each_with_index.map do |tokens, index|
        links = unit_path ? references.fetch(index + 1, []) : []
        LineRenderer.new(tokens, links, unit_path).html
      end
    end

    # @param source [String]
    # @param language [String]
    # @return [Array<Array>] CSS/value pairs per row
    def token_lines(source, language)
      out = [[]]
      syntax_tokens(source, language).each do |css, value|
        value.split("\n", -1).each_with_index do |part, index|
          out << [] if index.positive?
          out.last << [css, part] unless part.empty?
        end
      end
      out.pop if out.size > 1 && out.last.empty? && source.end_with?("\n")
      out
    end

    # @param source [String]
    # @param language [String]
    # @return [Array<Array(String, String)>] lossless CSS/value pairs
    def syntax_tokens(source, language)
      lexer = LEXERS[language.to_s]
      return [[nil, source]] unless lexer

      tokens = lexer.lex(source).map { |token, value| [class_for(token), value] }
      # A lexer must never change the source against which spans were validated.
      tokens.map(&:last).join == source ? tokens : [[nil, source]]
    end

    # @param token [Rouge::Token]
    # @return [String, nil]
    def class_for(token)
      name = token.qualname
      CLASSES.find { |prefix, _| name == prefix || name.start_with?("#{prefix}.") }&.last
    end

    # @param file_path [String, nil]
    # @return [String] the language key for a path
    def language_for(file_path)
      EXTENSIONS.fetch(File.extname(file_path.to_s), 'ruby')
    end

    # Consumes syntax-token bytes once, cutting tokens at validated link
    # boundaries. Each anchor and its syntax spans close within this row.
    class LineRenderer
      KIND_WORDS = { 'constant' => 'constant reference', 'association' => 'association',
                     'callback_method' => 'callback method', 'scope' => 'scope' }.freeze

      # @param tokens [Array<Array(String, String)>] CSS/value pairs
      # @param links [Array<WoodsMap::References::Link>] sorted, disjoint row intervals
      # @param unit_path [#call, nil] request-context identifier, type => URL
      def initialize(tokens, links, unit_path)
        @tokens = tokens.dup
        @links = links
        @unit_path = unit_path
        @column = 0
        @length = tokens.sum { |_, value| value.bytesize }
      end

      # @return [String] balanced, escaped row HTML
      def html
        out = +''
        @links.each do |link|
          out << take(link.column - @column)
          out << opening(link) << take(link.length) << (link.popover ? '</button>' : '</a>')
        end
        out << take(@length - @column)
      end

      private

      def take(length)
        out = +''
        while length.positive? && @tokens.any?
          css, value = @tokens.shift
          size = [length, value.bytesize].min
          escaped = escape(value.byteslice(0, size))
          out << (css ? "<span class=\"#{css}\">#{escaped}</span>" : escaped)
          @tokens.unshift([css, value.byteslice(size..)]) if size < value.bytesize
          @column += size
          length -= size
        end
        out
      end

      # An ambiguous span is a button for its candidates popover; every other
      # span links to its target, or to the method line it names.
      def opening(link)
        return open_tag('button', ambiguous_attributes(link)) if link.popover

        href = @unit_path.call(link.identifier, link.type)
        href = "#{href}#L#{link.line}" if link.line
        open_tag('a', 'href' => href, 'class' => link.confidence == 'static' ? 'const static' : 'const',
                      'data-target' => link.identifier, 'data-type' => link.type, 'data-kind' => link.kind,
                      'data-confidence' => link.confidence, 'data-method' => link.method,
                      'aria-label' => label(link))
      end

      def ambiguous_attributes(link)
        { 'type' => 'button', 'class' => 'const amb', 'aria-haspopup' => 'dialog', 'aria-expanded' => 'false',
          'aria-controls' => link.popover, 'data-action' => 'disambiguation#toggle', 'data-kind' => link.kind,
          'data-confidence' => 'ambiguous',
          'aria-label' => "#{link.text}, ambiguous reference: choose among its candidates" }
      end

      def label(link)
        subject = link.method ? "#{link.identifier}.#{link.method}" : link.identifier
        where = link.line ? ", line #{link.line}" : ''
        "#{subject} (#{link.type}#{where}), #{evidence(link)}"
      end

      def evidence(link)
        return 'static reference, not verified at runtime' if link.confidence == 'static'

        "verified #{KIND_WORDS.fetch(link.kind, 'reference')}"
      end

      def open_tag(name, attributes)
        "<#{name} #{attributes.compact.map { |key, value| "#{key}=\"#{escape(value.to_s)}\"" }.join(' ')}>"
      end

      def escape(value)
        # HTML normalizes literal CR to LF; a character reference retains CR.
        ERB::Util.html_escape(String.new(value)).gsub("\r", '&#13;')
      end
    end
    private_constant :LineRenderer
  end
end
