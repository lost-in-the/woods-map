# frozen_string_literal: true

# woods-map#49: every text role keeps 4.5:1 on the hover tint in both themes;
# --dim, which cannot, is lifted to --mut inside a hovered or selected row.
RSpec.describe WoodsMap::Assets do
  let(:tokens) { File.read(File.expand_path('../../docs/design/foundations/tokens.css', __dir__)) }
  let(:roles) { %w[bright text mut select link mod hot risk fresh] }

  def theme(selector)
    tokens[/^#{Regexp.escape(selector)}\{(.*?)^\}/m, 1].scan(/--([\w-]+):(#[0-9A-Fa-f]{6})/).to_h
  end

  def luminance(hex)
    channels = hex.delete('#').scan(/../).map { |c| c.to_i(16) / 255.0 }
    r, g, b = channels.map { |c| c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4 }
    (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
  end

  def contrast(foreground, background)
    light, dark = [luminance(foreground), luminance(background)].minmax.reverse
    (light + 0.05) / (dark + 0.05)
  end

  { 'dark' => '.wm', 'light' => '.wm[data-theme=light]' }.each do |name, selector|
    it "keeps every role at 4.5:1 on --hover in the #{name} theme" do
      colours = theme(selector)
      ratios = roles.index_with { |role| contrast(colours.fetch(role), colours.fetch('hover')).round(2) }
      expect(ratios.reject { |_, ratio| ratio >= 4.5 }).to eq({})
    end
  end

  it 'lifts --dim to --mut inside hovered and selected rows, and marks hover with an outline' do
    lift = /\.wm \.tbl tbody tr:hover,[^{]*\.wm \.palette \.hit\[aria-selected=true\]\{--dim:var\(--mut\)\}/
    expect(tokens).to match(lift)
    expect(tokens).to include('.wm .tbl tbody tr:hover{outline:1px solid var(--rule2);outline-offset:-1px}')
  end
end
