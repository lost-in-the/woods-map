# frozen_string_literal: true

require 'json'

module WoodsMap
  # One answer as server-sent events (M7): `tool` cards, `delta` text, then
  # one of `done`, `limited`, `cancelled` or `failed` carrying the turn and
  # its rendered HTML. No Action Cable and no Turbo: the panel's Stimulus
  # controller reads the stream with EventSource (`connect-src 'self'`).
  #
  # A turn streams once. A reconnect, which EventSource makes on its own
  # after the stream ends, gets the finished turn again instead of a second
  # model run. Proxies must not buffer this response (X-Accel-Buffering,
  # docs/DEPLOYMENT.md); while an answer runs, a heartbeat comment keeps a
  # quiet stream alive (`guide_heartbeat_seconds`).
  class GuideStreamsController < ApplicationController
    include ActionController::Live
    include WoodsMap::GuideSession

    FINISHED = %w[done limited cancelled failed].freeze

    def show
      store = guide_store
      turn = store.turn(params[:id].to_s)
      return head(:not_found) unless turn

      start_stream
      claimed = store.claim(turn['id'])
      claimed ? with_heartbeat { answer(store, claimed) } : replay(turn)
    rescue WoodsMap::Guide::Runner::Disconnected
      nil
    ensure
      response.stream.close
    end

    private

    def start_stream
      response.headers['Content-Type'] = 'text/event-stream'
      response.headers['Cache-Control'] = 'no-cache, no-store'
      response.headers['X-Accel-Buffering'] = 'no'
      response.headers['Last-Modified'] = Time.now.httpdate
      write_event('open', {})
    end

    def with_heartbeat
      @heartbeat = WoodsMap::Guide::Heartbeat.new(interval: woods_map_config.guide_heartbeat_seconds,
                                                  lock: stream_lock, write: ->(text) { response.stream.write(text) })
                                             .start
      yield
    ensure
      @heartbeat&.stop
    end

    def stream_lock
      @stream_lock ||= Mutex.new
    end

    def answer(store, turn)
      session = WoodsMap::Guide.open_session(woods_map_config, generation_key: generation_key)
      budget = WoodsMap::Guide::Budget.new(woods_map_config, tokens_spent: store.tokens)
      WoodsMap::Guide::Runner.new(store: store, turn: turn, session: session, emit: method(:emit), budget: budget).run
    rescue StandardError => e
      raise if e.is_a?(WoodsMap::Guide::Runner::Disconnected)

      failed = store.update_turn(turn['id']) do |record|
        record['state'] = 'failed'
        record['error'] = "#{e.class.name.split('::').last}: #{e.message}".slice(0, 300)
      end
      emit('failed', failed || turn)
    end

    # The generation the answer reads, so a pooled Index MCP server of an
    # older generation is not reused.
    def generation_key
      WoodsMap::Repository.open(&:generation_key)
    rescue WoodsMap::Repository::Unavailable
      nil
    end

    def replay(turn)
      if FINISHED.include?(turn['state'])
        emit(turn['state'], turn)
      else
        write_event('failed', 'message' => 'This answer is already streaming in another tab.')
      end
    end

    # Finished turns carry their rendered answer and its Trail links; links
    # come from the generation current when the answer ends.
    def emit(event, payload)
      payload = payload.merge(rendered(payload)) if FINISHED.include?(event)
      write_event(event, payload)
    end

    def rendered(turn)
      text = turn['answer'].to_s
      return { 'html' => '', 'trail' => {} } if text.empty?

      WoodsMap::Repository.open do |repository|
        answer = WoodsMap::Guide::Answer.new(text, identifiers: repository.identifier_index,
                                                   link: lambda { |identifier, type|
                                                     woods_map.unit_path(type: type, identifier: identifier)
                                                   })
        trail = WoodsMap::Guide::Handoff.links(turn, answer: answer,
                                                     generation: repository.generation_number) do |query|
          woods_map.trail_path(query)
        end
        { 'html' => answer.to_html, 'trail' => trail }
      end
    rescue WoodsMap::Repository::Unavailable
      { 'html' => WoodsMap::Guide::Answer.new(text, identifiers: {}, link: ->(*) { '#' }).to_html, 'trail' => {} }
    end

    def write_event(event, payload)
      raise WoodsMap::Guide::Runner::Disconnected if @heartbeat&.gone?

      stream_lock.synchronize do
        response.stream.write("event: #{event}\ndata: #{JSON.generate(payload)}\n\n")
        @heartbeat&.wrote
      end
    rescue IOError, Errno::EPIPE, ActionController::Live::ClientDisconnected
      raise WoodsMap::Guide::Runner::Disconnected
    end

    def render_unavailable(_error)
      head :service_unavailable
    end

    def refuse(_reason)
      head :forbidden
    end
  end
end
