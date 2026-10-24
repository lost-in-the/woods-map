# frozen_string_literal: true

module WoodsMap
  # Where each flow operation's target runs (C-1, notes/trail.md): the
  # caller's process for a call, the next process for an enqueue or a
  # `_later` mail delivery, with the hop that started it. Mixed into
  # {LifecycleBuilder}.
  module LifecycleReach
    # Delivery methods whose mailer action runs in another process.
    LATER = %w[deliver_later deliver_later!].freeze

    private

    # @param operations [Array<Hash>] one step's flow operations
    # @param label [String] the step they belong to
    # @param process [Integer] the step's process
    # @param reach [Hash{String => Array}] label => [process, via, hop, caller label], filled in
    def map_operations(operations, label, process, reach)
      each_operation(operations) do |op|
        case op[:type]&.to_sym
        when :async
          target = op[:target].to_s
          start_process(reach, [target, "#{target}#perform"], [process + 1, :async, true], op, label)
        when :callback then reach["#{op[:target]}##{op[:method]}"] ||= [process, :call, nil, label]
        when :call then map_call(op, label, process, reach)
        end
      end
    end

    def map_call(operation, label, process, reach)
      if operation[:mailer_action]
        later = LATER.include?(operation[:method].to_s)
        start_process(reach, [operation[:mailer_action]], [later ? process + 1 : process, :delivery, later],
                      operation, label)
      elsif operation[:target]
        reach[operation[:target].to_s] ||= [process, :call, nil, label]
        reach["#{operation[:target]}##{operation[:method]}"] ||= [process, :call, nil, label]
      end
    end

    # @param place [Array(Integer, Symbol, Boolean)] process, via and whether a new process starts
    def start_process(reach, labels, place, operation, from)
      return if labels.any? { |label| reach.key?(label) }

      process, via, new_process = place
      if new_process
        hop = LifecycleBuilder::Hop.new(n: process, label: labels.last, from: from, file: operation[:file],
                                        mechanism: "#{operation[:target]}.#{operation[:method]}",
                                        line: operation[:line])
      end
      labels.each { |label| reach[label] = [process, via, hop, from] }
    end

    def each_operation(operations, &block)
      operations.each do |op|
        yield op
        %i[nested then_ops else_ops].each { |key| each_operation(Array(op[key]), &block) }
      end
    end
  end
end
