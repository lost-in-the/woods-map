# frozen_string_literal: true

# The Mermaid build GitHub renders, vendored for the GitHub Mermaid spec only
# (woods-map#76; spec/vendor/github_mermaid/README.md), and what its parser
# calls each type the map's texts declare.
module GithubMermaidVendor
  VENDOR = File.expand_path('../vendor/github_mermaid', __dir__)
  BUILD = File.join(VENDOR, "mermaid-#{WoodsMap::MermaidExport::GITHUB_MERMAID_VERSION}.min.js.gz")
  DOM = File.join(VENDOR, 'linkedom-0.18.14.mjs')
  # SHA-256 of mermaid@11.16.1's unmodified dist/mermaid.min.js.
  BUILD_SHA256 = '18327bef70d96fb505fe7287d9f6a7362ebf07ff6576ddfaffb1a06f3e1a2954'

  # Pele's name for a declared type => the diagramType Mermaid's parser reports.
  DETECTED = { 'er' => 'er', 'sequence' => 'sequence', 'flowchart' => 'flowchart-v2', 'swimlane' => 'swimlane',
               'state' => 'stateDiagram', 'timeline' => 'timeline', 'xychart' => 'xychart',
               'quadrantChart' => 'quadrantChart', 'sankey' => 'sankey', 'treemap' => 'treemap', 'class' => 'class',
               'mindmap' => 'mindmap' }.freeze
end
