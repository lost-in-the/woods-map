# frozen_string_literal: true

module WoodsMap
  # The Domains tab's mindmap (B6-Overview's overview diagrams, woods-map#5):
  # the system at the root, each published domain cluster (woods#799) on the
  # first ring with its hub first, and the cluster's members on the second.
  # Clusters and members come in the order `graph_analysis.json` publishes
  # them; long clusters end in a count of the rest.
  class DomainMindmap
    # Members drawn per cluster before a count of the rest.
    MEMBERS = 8
    # Clusters drawn before the panel names the budget instead (R-4).
    CLUSTER_BUDGET = 30

    # @param clusters [Array<Hash>] `graph_analysis.json` `domain_clusters`
    # @param system_name [String]
    def initialize(clusters, system_name:)
      @clusters = Array(clusters)
      @system_name = system_name
    end

    # @return [String] Mermaid mindmap text
    def mermaid
      lines = ['mindmap', "  root((#{text(@system_name)}))"]
      @clusters.each do |cluster|
        lines << "    #{text(cluster['name'])}"
        members(cluster).each { |member| lines << "      #{text(member)}" }
      end
      lines.join("\n")
    end

    # @return [String, nil] why the mindmap is not drawn, nil within the budget
    def refusal
      return nil if @clusters.size <= CLUSTER_BUDGET

      "#{@clusters.size} clusters is over the mindmap budget of #{CLUSTER_BUDGET}; the table below lists every one"
    end

    private

    def members(cluster)
      names = Array(cluster['members']).map(&:to_s)
      hub = cluster['hub'].to_s
      names = ([hub] + (names - [hub])).reject(&:empty?)
      return names if names.size <= MEMBERS

      names.first(MEMBERS) + ["+#{names.size - MEMBERS} more"]
    end

    # Mindmap text: shape brackets and parentheses would open a node shape.
    def text(value)
      value.to_s.gsub(/[()\[\]{}"]/, ' ').squeeze(' ').strip.presence || '?'
    end
  end
end
