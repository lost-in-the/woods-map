# frozen_string_literal: true

require 'pathname'

module WoodsMap
  module Guide
    # The page-aware actions (design study, section 11). Each one is a prompt
    # template stored in the gem; a host overrides one by writing
    # `config/woods_map/prompts/<key>.md`. Templates take `{{context}}` (the
    # page's context block), `{{question}}` (anything typed with it) and,
    # for an action on an answer, `{{answer}}` (that answer's Markdown).
    module Actions
      # key => label and where it is offered. `pages` names page kinds
      # (:code, :unit, :lifecycle, :passage, :graph, :impact, :range); `types`
      # limits unit types; `needs` names context the action cannot run
      # without: :lines (selected code), :nodes (units selected on a graph)
      # or :answer (an earlier answer, for the actions an answer offers).
      LIST = {
        'explain_unit' => { label: 'explain this unit', pages: %i[code unit lifecycle passage graph] },
        'explain_method' => { label: 'explain this method', pages: %i[code], needs: :lines },
        'why_fail' => { label: 'why might this fail?', pages: %i[code unit lifecycle passage],
                        types: %w[job mailer controller model] },
        'plan_feature' => { label: 'plan a feature here', pages: %i[code unit] },
        'blast_radius' => { label: 'summarise blast radius', pages: %i[code unit graph impact] },
        'explain_lifecycle' => { label: 'explain lifecycle', pages: %i[lifecycle] },
        'explain_passage' => { label: 'explain this passage', pages: %i[passage] },
        'review_change' => { label: 'review this change', pages: %i[impact range] },
        'explain_selection' => { label: 'explain the selected units', pages: %i[graph], needs: :nodes },
        # Offered under an answer, never in the page's row: the draft is text
        # to copy; the map never posts it anywhere.
        'draft_issue' => { label: 'draft an issue', pages: [], needs: :answer }
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
      # @param answer [String, nil] the earlier answer an answer action works from
      # @return [String]
      def prompt(key, context:, question:, answer: nil)
        template = key ? template(key) : "{{context}}\n\nQuestion: {{question}}\n"
        # One pass, so text a value carries is never read as another placeholder.
        values = { 'context' => context.to_s, 'question' => question.to_s.strip.presence || '(none)',
                   'answer' => answer.to_s.strip.presence || '(none)' }
        template.gsub(/\{\{(context|question|answer)\}\}/) { values.fetch(Regexp.last_match(1)) }
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
