# frozen_string_literal: true

require 'date'

# Folds changelog/<type>_<slug>.md entry files into CHANGELOG.md. The entry
# format and types match Woods' own fragments; this is a small copy so the
# development task needs no dependency on the woods gem.
module ChangelogFragments
  class Error < StandardError; end
  class InvalidEntry < Error; end

  HEADINGS = ['Added', 'Build', 'Changed', 'Dependencies', 'Documentation', 'Fixed',
              'Performance', 'Security', 'Testing', 'Upgrade Notes'].to_h do |heading| # rubocop:disable Rails/IndexBy
    [heading.downcase.tr(' ', '-'), heading]
  end.freeze
  FILENAME = /\A(?<type>[a-z-]+)_[a-z0-9][a-z0-9_-]*\.md\z/
  HEADING = /(?:^ {0,3}\#{1,6}(?:\s|$)|^ {0,3}\S[^\n]*\n {0,3}(?:=+|-+)[ \t]*\r?$)/
  VERSION = /\A\d+\.\d+\.\d+(?:\.[0-9A-Za-z.]+)?\z/
  UNRELEASED = "## [Unreleased]\n"
  POINTER = 'Add a file under `changelog/` instead of editing this section. See `changelog/README.md`.'

  module_function

  # @return [Array<String>] relative paths of the folded fragments (empty when there were none)
  def fold(root:, version:, date: Time.now.utc.to_date)
    raise Error, "#{version.inspect} is not a version like 1.2.3" unless VERSION.match?(version.to_s)

    entries = read(root)
    return [] if entries.empty?

    path = File.join(root, 'CHANGELOG.md')
    File.write(path, folded(File.read(path, encoding: Encoding::UTF_8), version, date, entries.values))
    entries.each_key { |relative| File.unlink(File.join(root, relative)) }
    entries.keys
  end

  # @return [Hash<String, Array(String, String)>] relative path to heading/body, validated as a set
  def read(root)
    directory = File.join(root, 'changelog')
    return {} unless File.directory?(directory)

    Dir.children(directory).sort.grep(/\.md\z/).reject { |name| name == 'README.md' }.to_h do |name|
      ["changelog/#{name}", read_entry(File.join(directory, name), "changelog/#{name}", name)]
    end
  end

  def read_entry(file, path, name)
    match = FILENAME.match(name)
    heading = match && HEADINGS[match[:type]]
    raise InvalidEntry, "#{path}: expected <type>_<slug>.md; types: #{HEADINGS.keys.join(', ')}" unless heading
    raise InvalidEntry, "#{path}: entry must be a regular file" unless File.lstat(file).file?

    body = File.read(file, encoding: Encoding::UTF_8)
    unless body.valid_encoding? && !body.strip.empty? && !body.match?(HEADING)
      raise InvalidEntry, "#{path}: entry must be nonempty UTF-8 Markdown without headings"
    end
    raise InvalidEntry, "#{path}: entry must begin with a '- ' list item" unless body.lstrip.match?(/\A-[ \t]+\S/)

    [heading, body.strip]
  end

  def folded(source, version, date, entries)
    if source.match?(/^## \[#{Regexp.escape(version)}\]/)
      raise Error, "CHANGELOG.md already has a heading for #{version}"
    end

    head, rest = source.split(UNRELEASED, 2)
    raise Error, 'CHANGELOG.md has no "## [Unreleased]" heading' unless rest

    body, tail = rest.split(/^(?=## \[)/, 2)
    unless body.strip == POINTER
      raise Error, 'the Unreleased section holds entries; move each into a changelog/<type>_<slug>.md file'
    end

    heading = "## [#{version}] - #{date.strftime('%Y-%m-%d')}"
    "#{head}#{UNRELEASED}\n#{POINTER}\n\n#{heading}\n\n#{render(entries)}#{"\n#{tail}" if tail}"
  end

  def render(entries)
    entries.group_by(&:first).sort_by { |heading, _| HEADINGS.values.index(heading) }.map do |heading, group|
      "### #{heading}\n\n#{group.map(&:last).join("\n")}\n"
    end.join("\n")
  end
end
