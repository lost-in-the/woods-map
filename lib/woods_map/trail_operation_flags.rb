# frozen_string_literal: true

module WoodsMap
  # Trail flags backed by published flow operations, including nested branches.
  module TrailOperationFlags
    private

    def operation_flags(step)
      flags = []
      each_operation(step.operations) do |operation|
        flags << ambiguous_flag(step, operation) if operation.key?(:ambiguous_candidates)
        case operation[:type]&.to_sym
        when :conditional
          if operation[:kind].to_s == 'if' && Array(operation[:else_ops]).empty?
            flags << flag(step.identity, :no_else, "if #{operation[:condition]} has no else operations",
                          'flow conditional', operation)
          end
        when :dynamic_dispatch
          text = "#{operation[:target]}.#{operation[:method]}: the target is not resolved"
          flags << flag(step.identity, :dynamic, text,
                        'flow dynamic_dispatch', operation)
        end
      end
      flags
    end

    def ambiguous_flag(step, operation)
      found = flag(step.identity, :ambiguous, "? ambiguous call in #{step.title} .#{operation[:method]}",
                   'flow ambiguous_candidates', operation)
      found.candidates = Array(operation[:ambiguous_candidates])
      found
    end
  end
end
