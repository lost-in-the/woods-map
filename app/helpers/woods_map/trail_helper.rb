# frozen_string_literal: true

module WoodsMap
  # Helpers for the Trail (notes/trail.md): step titles and links, pin
  # toggles and the board's own URLs, all from the board's query.
  module TrailHelper
    # Operation kinds as the steps table reads them.
    OPERATION_WORDS = { 'async' => 'enqueues', 'callback' => 'callback', 'call' => 'calls', 'conditional' => 'if',
                        'dynamic_dispatch' => 'dispatches', 'transaction' => 'transaction',
                        'response' => 'responds' }.freeze

    # @param query [Hash] a board query ({TrailBoard#to_query})
    # @return [String]
    def trail_board_path(query)
      woods_map.trail_path(query)
    end

    # @param step [LifecycleBuilder::Step]
    # @return [String] `Unit#method`, `Unit@event` or the template
    def trail_step_title(step)
      return step.label if step.type == 'model_event' || step.method_name.nil?

      "#{step.unit}##{step.method_name}"
    end

    # @param step [LifecycleBuilder::Step]
    # @return [ActiveSupport::SafeBuffer] the step's unit page; a model event opens the Lifecycle tab
    def trail_step_link(step)
      identifier, type = step.identity
      if step.type == 'model_event'
        return link_to(trail_step_title(step),
                       woods_map.unit_lifecycle_path(type: type, identifier: identifier))
      end
      return ERB::Util.html_escape(trail_step_title(step)) unless current_repository.graph_node(identifier, type: type)

      link_to(trail_step_title(step), woods_map.unit_path(type: type, identifier: identifier))
    end

    # @param board [TrailBoard]
    # @param identity [Array(String, String)] identifier and type
    # @return [ActiveSupport::SafeBuffer] a link that pins or unpins the unit
    def trail_pin_toggle(board, identity)
      pin = TrailBoard::Pin.new(identifier: identity.first, type: identity.last)
      if board.pinned?(pin)
        link_to('unpin', trail_board_path(board.without_pin(pin)), class: 'tool',
                                                                   'aria-label': "Unpin #{identity.first}")
      elsif board.pins.size < TrailBoard::MAX_PINS
        link_to('pin', trail_board_path(board.with_pin(pin)), class: 'tool', 'aria-label': "Pin #{identity.first}")
      end
    end

    # @param hop [LifecycleBuilder::Hop]
    # @return [ActiveSupport::SafeBuffer] the async boundary's label
    def trail_hop_text(hop)
      where = hop.file ? code_line_link(hop.file, hop.line) : nil
      safe_join(["⇒ async hop, new process: #{hop.label}", (" from #{hop.from}" if hop.from), " (#{hop.mechanism}",
                 (where ? safe_join([', ', where]) : nil), ')'].compact)
    end

    # @param operation [Hash] a flow operation
    # @return [String] one line: kind, target and method
    def trail_operation_text(operation)
      op = operation
      kind = op[:type].to_s
      word = OPERATION_WORDS.fetch(kind, kind)
      case kind
      when 'callback' then "#{op[:callback]} #{op[:method]}#{" (#{op[:unexpanded]})" if op[:unexpanded]}"
      when 'conditional' then "#{op[:kind]} #{op[:condition]}"
      when 'transaction' then "transaction on #{op[:receiver]}"
      when 'response' then "responds #{op[:status_code]}"
      else
        target = [op[:target], op[:method]].compact.join('.')
        mailer = op[:mailer_action] ? " → #{op[:mailer_action]}" : ''
        "#{word} #{target}#{mailer}"
      end
    end

    # @param flag [TrailFlags::Flag]
    # @return [ActiveSupport::SafeBuffer]
    def trail_flag_chip(flag)
      flag.severity == :warn ? chip(:risk, flag.rule) : chip(:note, flag.rule)
    end
  end
end
