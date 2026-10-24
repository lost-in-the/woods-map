# frozen_string_literal: true

require 'set'
require 'time'

module WoodsMap
  # `/woods/history` (FR-7, A-6): one lane per selected unit across the
  # window, a dot per commit that touched the unit's files, and the commits
  # that touched two or more selected units drawn as connected pairs: the
  # "who changed the mailer and the job together" question of design-study
  # scenario 2, answered from the commit table alone. Units are named by
  # typed identifier in the URL (`units[]=job:NotifySubscribersJob`).
  class HistoryTimeline
    # One selected unit.
    Lane = Struct.new(:identifier, :type, :paths, :shas, keyword_init: true)
    # One commit with the lanes it touches and every unit it touched.
    Event = Struct.new(:sha, :author, :date, :message, :description, :lanes, :units, keyword_init: true)
    # Two lanes and the commits they share.
    Pair = Struct.new(:left, :right, :shas, keyword_init: true)

    MAX_LANES = 12
    EVENT_LIMIT = 500

    # @param repository [WoodsMap::Repository]
    # @param selection [Array<String>, String, nil] `type:identifier` or a bare identifier
    # @param days [Integer]
    # @param now [Time]
    # @param filters [Hash] `author:` only commits whose author, as git
    #   recorded it, is exactly this; `span:` (Range<Date>) only the days a
    #   drag picked ({DateSpan})
    def initialize(repository, selection, days: 365, now: Time.now.utc, **filters)
      author = filters[:author]
      @span = filters[:span]
      @repository = repository
      @table = repository.git_commits
      @days = days
      @now = now
      @author = author.to_s.presence
      @lanes, @unknown = resolve(Array(selection).grep(String).first(MAX_LANES))
    end

    # @return [Range<Date>, nil] the days a drag picked
    attr_reader :span

    # @return [Array<Lane>]
    attr_reader :lanes
    # @return [Array<String>] selections no unit of this generation answers
    attr_reader :unknown
    # @return [Integer]
    attr_reader :days
    # @return [String, nil] the author the events are narrowed to (woods-map#92)
    attr_reader :author

    # @return [Boolean] whether there is a commit table to draw from
    def table?
      !@table.nil?
    end

    # @return [Boolean] whether no unit was selected
    delegate :empty?, to: :@lanes

    # Commits that touched any selected unit inside the window, newest first,
    # by {#author} and inside {#span} when they are set.
    #
    # @return [Array<Event>]
    def events
      @events ||= window_events.select { |event| (!@author || event.author == @author) && in_span?(event) }
                               .first(EVENT_LIMIT)
    end

    # @return [Array<String>] the window's authors, most commits first
    def authors
      window_events.group_by(&:author).sort_by { |name, list| [-list.size, name.to_s] }.map(&:first).compact
    end

    # Lane pairs that changed together, most shared commits first.
    #
    # @return [Array<Pair>]
    def pairs
      found = @lanes.each_index.to_a.combination(2).filter_map do |left, right|
        shared = events.select { |event| event.lanes.include?(left) && event.lanes.include?(right) }.map(&:sha)
        Pair.new(left: @lanes[left], right: @lanes[right], shas: shared) if shared.any?
      end
      found.sort_by { |pair| -pair.shas.size }
    end

    # @return [CommitStrip] the window's axis
    def strip
      @strip ||= CommitStrip.new(events.map(&:date), days: @days, now: @now)
    end

    # @param date [String]
    # @return [Float] the x position, 0 (window start) to 1 (today)
    def position(date)
      time = parse(date)
      return 0.0 unless time

      start = @now - (@days * 86_400)
      ((time - start) / (@now - start)).clamp(0.0, 1.0)
    end

    # @return [Array<Hash>] the most-changed units of the window, for the picker
    def suggestions
      return [] unless table?

      counts = Hash.new(0)
      @table.paths.each do |path, shas|
        @repository.file_owners(path).each { |owner| counts[[owner['type'], owner['identifier']]] += shas.size }
      end
      counts.sort_by { |(type, identifier), count| [-count, type.to_s, identifier.to_s] }.first(16)
            .map { |(type, identifier), count| { 'type' => type, 'identifier' => identifier, 'commits' => count } }
    end

    # @return [String] the timeline's Mermaid text
    def mermaid
      HistoryMermaid.timeline("#{@lanes.map(&:identifier).join(', ')}, #{@days}d", events)
    end

    # @return [Array<String>] the selection as it goes back into a URL
    def selection
      @lanes.map { |lane| "#{lane.type}:#{lane.identifier}" }
    end

    private

    def window_events
      return [] unless table?

      @window_events ||= begin
        cutoff = @now - (@days * 86_400)
        @table.commits_for(*@lanes.flat_map(&:paths)).filter_map do |row|
          time = parse(row['date'])
          next unless time && time >= cutoff

          event(row)
        end
      end
    end

    def in_span?(event)
      !@span || DateSpan.cover?(@span, event.date)
    end

    def resolve(selection)
      lanes = []
      unknown = []
      selection.uniq.each do |value|
        unit = lookup(value)
        next unknown << value unless unit

        paths = UnitPaths.for(@repository, unit)
        lanes << Lane.new(identifier: unit['identifier'], type: unit['type'], paths: paths,
                          shas: table? ? @table.commits_for(*paths).to_set { |row| row['sha'] } : Set.new)
      end
      [lanes.uniq { |lane| [lane.identifier, lane.type] }, unknown]
    end

    def lookup(value)
      type, identifier = if value.include?(':') && value.split(':',
                                                               2).first.match?(/\A[a-z0-9_]+\z/)
                           value.split(':',
                                       2)
                         else
                           [nil,
                            value]
                         end
      type ||= @repository.identifier_types(identifier).first
      type && @repository.unit(identifier, type: type)
    end

    def event(row)
      lanes = @lanes.each_index.select { |index| @lanes[index].shas.include?(row['sha']) }
      units = Array(row['files']).flat_map { |file| @repository.file_owners(file['path']) }
                                 .map { |owner| [owner['identifier'], owner['type']] }.uniq
      Event.new(sha: row['sha'], author: row['author'], date: row['date'], message: row['message'],
                description: row['description'].to_s, lanes: lanes, units: units)
    end

    def parse(value)
      Time.iso8601(value.to_s).utc
    rescue ArgumentError
      nil
    end
  end
end
