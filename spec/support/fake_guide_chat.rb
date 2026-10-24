# frozen_string_literal: true

module WoodsMap
  # A chat with RubyLLM's step-wise surface and a script instead of a
  # provider: no network, no model. Each scripted step either runs tool calls
  # (firing before_tool_call and after_tool_result) or answers with text,
  # streamed in chunks, with the token usage it reports.
  class FakeGuideChat
    Chunk = Struct.new(:content)
    Tokens = Struct.new(:input, :output)
    Message = Struct.new(:role, :content, :tokens)
    ToolCall = Struct.new(:id, :name, :arguments)
    Result = Struct.new(:text, :failed) do
      def error?
        failed
      end
    end

    attr_reader :messages, :cancelled

    # @param steps [Array<Hash>] { tools: [[name, args, failed?]] } or { text:, tokens: [in, out] }
    # @param on_step [#call, nil] called before each step, for specs that stop mid-answer
    def initialize(steps, on_step: nil)
      @steps = steps.map(&:dup)
      @on_step = on_step
      @messages = []
      @callbacks = Hash.new { |hash, key| hash[key] = [] }
      @calls = 0
    end

    def ask_later(prompt)
      @messages << Message.new(:user, prompt, nil)
      self
    end

    def add_message(role:, content:)
      @messages << Message.new(role, content, nil)
    end

    %i[before_tool_call after_tool_result after_message].each do |name|
      define_method(name) do |&block|
        @callbacks[name] << block
        self
      end
    end

    def complete?
      @steps.empty?
    end

    def step(&stream)
      @on_step&.call(self)
      step = @steps.shift
      step[:tools] ? run_tools(step[:tools]) : answer(step, &stream)
    end

    def cancel
      @cancelled = true
      self
    end

    private

    def run_tools(tools)
      tools.each do |name, arguments, failed|
        call = ToolCall.new("call_#{@calls += 1}", name, arguments)
        fire(:before_tool_call, call)
        fire(:after_tool_result, Result.new("#{name} result", failed))
        @messages << Message.new(:tool, "#{name} result", nil)
      end
      nil
    end

    def answer(step, &stream)
      text = step.fetch(:text)
      text.scan(/.{1,12}/m).each { |piece| stream&.call(Chunk.new(piece)) }
      message = Message.new(:assistant, text, Tokens.new(*step.fetch(:tokens, [0, 0])))
      @messages << message
      fire(:after_message, message)
      message
    end

    def fire(name, value)
      @callbacks[name].each { |callback| callback.call(value) }
    end
  end
end
