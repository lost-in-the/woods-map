# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'securerandom'
require 'time'

module WoodsMap
  module Guide
    # One browser session's guide state, kept as JSON under the chats
    # directory (`<index_dir>/explorer/chats` by default, outside every
    # payload, so extraction and the exporters never see it; F-4): the
    # tokens the session has spent and the current conversation's turns.
    # "new" starts another conversation and keeps the spend, so the budget
    # holds for the whole session; the conversation it leaves joins the
    # session's history, the newest {HISTORY} kept, and can be opened again.
    # Nothing is written to the host database.
    class Store
      # A session id: 32 hex characters, generated here, never a path.
      ID = /\A[0-9a-f]{32}\z/

      # A conversation id: 16 hex characters, generated here.
      CONVERSATION = /\A[0-9a-f]{16}\z/

      # Earlier conversations kept per session; the oldest is dropped.
      HISTORY = 20

      # The longest title a history row shows.
      TITLE = 80

      # Raised when the current conversation is still answering.
      class Busy < StandardError; end

      # Raised for an id that is not one this store issued.
      class InvalidId < ArgumentError; end

      LOCK = Mutex.new
      private_constant :LOCK

      # @return [String]
      attr_reader :id

      # @return [String] a fresh session id
      def self.generate_id
        SecureRandom.hex(16)
      end

      # @param dir [Pathname, String]
      # @param id [String]
      # @raise [InvalidId]
      def initialize(dir, id)
        raise InvalidId, 'not a guide session id' unless id.is_a?(String) && id.match?(ID)

        @dir = Pathname.new(dir.to_s)
        @id = id
      end

      # @return [Hash] the session record
      def data
        LOCK.synchronize { read }
      end

      # @return [Array<Hash>] the current conversation's turns
      def turns
        Array(data['turns'])
      end

      # @param turn_id [String]
      # @return [Hash, nil]
      def turn(turn_id)
        turns.find { |turn| turn['id'] == turn_id }
      end

      # @return [Integer] tokens the session has spent
      def tokens
        data['tokens'].to_i
      end

      # Add a pending turn.
      #
      # @param attributes [Hash] question, action, prompt, context
      # @return [Hash] the turn, with its id
      def add_turn(attributes)
        turn = attributes.transform_keys(&:to_s).merge(
          'id' => SecureRandom.hex(8), 'state' => 'pending', 'created_at' => Time.now.utc.iso8601,
          'answer' => '', 'tool_calls' => []
        )
        change { |record| record['turns'] = Array(record['turns']) + [turn] }
        turn
      end

      # Change one turn in place.
      #
      # @param turn_id [String]
      # @yieldparam turn [Hash]
      # @return [Hash, nil] the changed turn
      def update_turn(turn_id)
        changed = nil
        change do |record|
          changed = Array(record['turns']).find { |turn| turn['id'] == turn_id }
          yield changed if changed
        end
        changed
      end

      # Claim a pending turn for streaming, once.
      #
      # @param turn_id [String]
      # @return [Hash, nil] the turn, or nil when it is not pending
      def claim(turn_id)
        claimed = nil
        change do |record|
          turn = Array(record['turns']).find { |candidate| candidate['id'] == turn_id }
          next unless turn && turn['state'] == 'pending'

          turn['state'] = 'running'
          claimed = turn
        end
        claimed
      end

      # @param count [Integer]
      # @return [void]
      def add_tokens(count)
        change { |record| record['tokens'] = record['tokens'].to_i + count.to_i }
      end

      # Start a new conversation; the session's spend stays and the one left
      # joins the history.
      #
      # @return [void]
      def reset!
        change do |record|
          archive(record)
          record['turns'] = []
          record['conversation'] = SecureRandom.hex(8)
        end
      end

      # @return [String] the current conversation's id
      def conversation
        data['conversation'].to_s
      end

      # The session's conversations, the current one first, then the
      # history newest first: id, title, turn count, when it started and
      # when it last changed. A conversation with no turns is left out.
      #
      # @return [Array<Hash>]
      def conversations
        record = data
        current = Array(record['turns']).any? ? [summary(record['conversation'], record['turns'], current: true)] : []
        current + Array(record['history']).map { |entry| summary(entry['id'], entry['turns'], current: false) }
      end

      # Make an earlier conversation the current one again; the current one
      # joins the history.
      #
      # @param conversation_id [String]
      # @return [Boolean] false when the session has no such conversation
      # @raise [Busy] while the current conversation is answering
      def open!(conversation_id)
        return false unless conversation_id.to_s.match?(CONVERSATION)

        opened = false
        change do |record|
          raise Busy, 'An answer is still streaming.' if answering?(record)
          next opened = true if record['conversation'] == conversation_id

          entry = Array(record['history']).find { |candidate| candidate['id'] == conversation_id }
          next unless entry

          record['history'] = Array(record['history']) - [entry]
          archive(record)
          record['conversation'] = entry['id']
          record['turns'] = Array(entry['turns'])
          opened = true
        end
        opened
      end

      private

      def path
        @dir.join("#{@id}.json")
      end

      def read
        return blank unless path.file?

        JSON.parse(File.read(path, encoding: 'UTF-8'))
      rescue JSON::ParserError
        blank
      end

      def archive(record)
        turns = Array(record['turns'])
        return if turns.empty?

        id = record['conversation'].to_s
        entry = { 'id' => id.match?(CONVERSATION) ? id : SecureRandom.hex(8), 'turns' => turns }
        record['history'] = ([entry] + Array(record['history'])).first(HISTORY)
      end

      def answering?(record)
        Array(record['turns']).any? { |turn| %w[pending running].include?(turn['state']) }
      end

      def summary(id, turns, current:)
        turns = Array(turns)
        first = turns.first || {}
        title = first['label'] || first['question']
        title = "#{title}: #{first['question']}" if first['label'] && first['question'].to_s != ''
        title = title.to_s.strip
        title = "#{title[0, TITLE - 1]}…" if title.size > TITLE
        { 'id' => id.to_s, 'title' => title, 'summary' => first.dig('context', 'summary').to_s,
          'turns' => turns.size, 'started_at' => first['created_at'], 'updated_at' => turns.last&.dig('created_at'),
          'current' => current }
      end

      def blank
        { 'id' => @id, 'tokens' => 0, 'conversation' => SecureRandom.hex(8), 'turns' => [] }
      end

      def change
        LOCK.synchronize do
          FileUtils.mkdir_p(@dir)
          File.open(@dir.join(".#{@id}.lock"), File::RDWR | File::CREAT, 0o600) do |lock|
            lock.flock(File::LOCK_EX)
            record = read
            yield record
            write(record)
          end
        end
      end

      def write(record)
        temporary = @dir.join(".#{@id}.#{SecureRandom.hex(4)}.tmp")
        File.write(temporary, JSON.generate(record), encoding: 'UTF-8', perm: 0o600)
        File.rename(temporary, path)
      end
    end
  end
end
