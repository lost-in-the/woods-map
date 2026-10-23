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
          out << anchor(link) << take(link.length) << '</a>'
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

      def anchor(link)
        attributes = {
          'href' => @unit_path.call(link.identifier, link.type), 'class' => 'const',
          'data-target' => link.identifier, 'data-type' => link.type, 'data-kind' => link.kind,
          'aria-label' => "#{link.identifier} (#{link.type}), verified constant reference"
        }
        "<a #{attributes.map { |name, value| "#{name}=\"#{escape(value.to_s)}\"" }.join(' ')}>"
      end

      def escape(value)
        # HTML normalizes literal CR to LF; a character reference retains CR.
        ERB::Util.html_escape(String.new(value)).gsub("\r", '&#13;')
      end
    end
    private_constant :LineRenderer
  end
end
