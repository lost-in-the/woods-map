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
    # @return [Array<String>] HTML for each line, in order
    def lines(source, language: 'ruby')
      lexer = LEXERS[language.to_s]
      return source.lines.map { |line| ERB::Util.html_escape(line.chomp) } unless lexer

      out = [+'']
      lexer.lex(source).each { |token, value| append(out, class_for(token), value) }
      out.pop if out.size > 1 && out.last.empty? && source.end_with?("\n")
      out
    end

    # Append one token's value to the line buffer, opening a new line at
    # each newline it contains.
    #
    # @param out [Array<String>]
    # @param css [String, nil]
    # @param value [String]
    # @return [void]
    def append(out, css, value)
      value.split("\n", -1).each_with_index do |part, index|
        out << +'' if index.positive?
        next if part.empty?

        escaped = ERB::Util.html_escape(part)
        out[-1] << (css ? "<span class=\"#{css}\">#{escaped}</span>" : escaped)
      end
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
  end
end
