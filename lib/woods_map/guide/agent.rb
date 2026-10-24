# frozen_string_literal: true

# Loaded only by {WoodsMap::Guide.backend}, after `ruby_llm` (Ruby 3.2+).
module WoodsMap
  module Guide
    # The Woods Index MCP server the agent reads through (D-7): stdio to
    # `woods-mcp` over the host's published index by default, or a deployed
    # `woods-mcp-http`. Only the read-only allow-list reaches the model.
    class IndexMcp < RubyLLM::MCP
      self.default_name = 'woods'
      only(*Guide::TOOLS)
      timeout 60

      # The class for the current configuration: stdio unless a URL is set.
      #
      # @param config [WoodsMap::Configuration]
      # @return [Class] a subclass carrying the transport settings
      def self.for(config)
        Class.new(self) do
          self.default_name = 'woods'
          if config.guide_mcp_url
            url config.guide_mcp_url
            bearer_token config.guide_mcp_token if config.guide_mcp_token
          else
            command(*IndexMcp.command_for(config))
            directory Rails.root.to_s if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
          end
        end
      end

      # @param config [WoodsMap::Configuration]
      # @return [Array<String>] the stdio command
      def self.command_for(config)
        Array(config.guide_mcp_command).presence || ['bundle', 'exec', 'woods-mcp', config.index_path.to_s]
      end
    end

    # The guide agent: index tools only, identifiers cited exactly, nothing
    # claimed that the index cannot prove. The host chooses provider and model
    # through RubyLLM's configuration and `config.guide_chat_options`.
    class Agent < RubyLLM::Agent
      instructions <<~TXT
        You answer questions about one Rails application using only the Woods index tools.
        Cite units by their exact identifier, for example Post or PostsController, and write
        method names as Identifier#method. Say when a flow step is unexpanded or a fact is
        missing from the index. Never claim runtime behaviour the index cannot prove; you
        see application source and extracted metadata, never live data. Answer in short
        Markdown: paragraphs, lists and `code`; no HTML, no images, no links.
      TXT
    end
  end
end
