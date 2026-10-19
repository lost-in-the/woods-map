# frozen_string_literal: true

module WoodsMap
  # The glyph vocabulary (D-20): every mark in the map is a Unicode character
  # in the text, coloured by the token it sits in. One glyph, one meaning,
  # everywhere; a new need adds a row here first (docs/design/foundations/glyphs.md).
  module Glyphs
    # name => [glyph, meaning, where]
    VOCABULARY = {
      closed: ['+', 'closed (row toggle)', 'subdivided rows'],
      open: ['−', 'open (row toggle)', 'subdivided rows'],
      folded: ['▸', 'closed', 'accordions, tree folders'],
      unfolded: ['▾', 'open', 'accordions, tree folders'],
      call: ['→', 'call', 'steps, legends, sequence'],
      async: ['⇒', 'async hop', 'steps, legends, sequence'],
      return: ['⇢', 'return', 'steps, legends, sequence'],
      flag: ['⚑', 'risk (red), warning (orange)', 'chips, rail, diagrams, tree'],
      current: ['●', 'current; one (ER)', 'top bar, legends'],
      stale: ['○', 'stale index; many (ER); static reference', 'top bar, legends, code'],
      search: ['⌕', 'search', 'top bar'],
      menu: ['☰', 'menu', 'top bar, panels'],
      close: ['✕', 'close', 'panels'],
      info: ['ⓘ', 'explain', 'section headers'],
      copy: ['⎘', 'copy', 'tools'],
      external: ['↗', 'open outside', 'tools'],
      collapse: ['‹', 'collapse', 'tree strip'],
      expand: ['›', 'expand', 'tree strip, breadcrumb'],
      sequence: ['↕', 'sequence', 'the diagram icon rail'],
      flowchart: ['⤵', 'flowchart', 'the diagram icon rail'],
      lanes: ['≡', 'lanes', 'the diagram icon rail'],
      up: ['▲', 'up', 'trend cells'],
      down: ['▼', 'down', 'trend cells'],
      sortable: ['⇅', 'sortable', 'table heads'],
      none: ['—', 'not applicable', 'empty cells'],
      more: ['…', 'more', 'truncated paths'],
      check: ['✓', 'passing, done', 'chips, tests'],
      warning: ['⚠', 'warning', 'banners'],
      ambiguous: ['?', 'ambiguous reference', 'code']
    }.freeze

    # @param name [Symbol]
    # @return [String] the glyph
    # @raise [KeyError] for a name outside the vocabulary
    def self.[](name)
      VOCABULARY.fetch(name).first
    end
  end
end
