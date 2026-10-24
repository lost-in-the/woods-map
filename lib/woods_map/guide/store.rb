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
    # holds for the whole session. Nothing is written to the host database.
    class Store
      # A session id: 32 hex characters, generated here, never a path.
      ID = /\A[0-9a-f]{32}\z/

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

      # Start a new conversation; the session's spend stays.
      #
      # @return [void]
      def reset!
        change do |record|
          record['turns'] = []
          record['conversation'] = SecureRandom.hex(8)
        end
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
