# frozen_string_literal: true

require 'pathname'

module WoodsMap
  module Guide
    # The page-aware actions (design study, section 11). Each one is a prompt
    # template stored in the gem; a host overrides one by writing
    # `config/woods_map/prompts/<key>.md`. Templates take `{{context}}` (the
    # page's context block) and `{{question}}` (anything typed with it).
    module Actions
      # key => label and where it is offered. `pages` names page kinds
      # (:code, :unit, :lifecycle, :passage, :impact, :range); `types` limits
      # unit types; `needs` names context the action cannot run without.
      LIST = {
        'explain_unit' => { label: 'explain this unit', pages: %i[code unit lifecycle passage] },
        'explain_method' => { label: 'explain this method', pages: %i[code], needs: :lines },
        'why_fail' => { label: 'why might this fail?', pages: %i[code unit lifecycle passage],
                        types: %w[job mailer controller model] },
        'plan_feature' => { label: 'plan a feature here', pages: %i[code unit] },
        'blast_radius' => { label: 'summarise blast radius', pages: %i[code unit impact] },
        'explain_lifecycle' => { label: 'explain lifecycle', pages: %i[lifecycle] },
        'explain_passage' => { label: 'explain this passage', pages: %i[passage] },
        'review_change' => { label: 'review this change', pages: %i[impact range] }
      }.freeze

      # The gem's own templates.
      PROMPTS = Pathname.new(File.expand_path('prompts', __dir__))

      module_function

      # @param page [Symbol, nil] the page kind
      # @param type [String, nil] the unit type
      # @return [Array<String>] action keys offered on that page, in order
      def for(page, type: nil)
        return [] if page.nil?

        LIST.select do |_, action|
          action[:pages].include?(page) && (action[:types].nil? || action[:types].include?(type.to_s))
        end.keys
      end

      # @param key [String]
      # @return [Boolean]
      def known?(key)
        LIST.key?(key.to_s)
      end

      # @param key [String]
      # @return [String]
      def label(key)
        LIST.fetch(key.to_s)[:label]
      end

      # The prompt sent to the model for an action, or for a typed question.
      #
      # @param key [String, nil] an action key, or nil for a free question
      # @param context [String] the context block
      # @param question [String] what the person typed, possibly empty
      # @return [String]
      def prompt(key, context:, question:)
        template = key ? template(key) : "{{context}}\n\nQuestion: {{question}}\n"
        template.gsub('{{context}}', context.to_s).gsub('{{question}}', question.to_s.strip.presence || '(none)')
      end

      # @param key [String]
      # @return [String] the host's override, else the gem's template
      def template(key)
        raise ArgumentError, "unknown guide action #{key.inspect}" unless known?(key)

        override = host_prompts&.join("#{key}.md")
        (override&.file? ? override : PROMPTS.join("#{key}.md")).read(encoding: 'UTF-8')
      end

      # @return [Pathname, nil]
      def host_prompts
        Rails.root.join('config/woods_map/prompts') if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
      end
    end
  end
end
