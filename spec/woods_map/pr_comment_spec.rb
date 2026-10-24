# frozen_string_literal: true

RSpec.describe WoodsMap::PrComment do
  let(:view_url) { 'https://map.example.com/woods/units/model/User/lifecycle?event=update' }
  let(:mmd) { 'https://map.example.com/woods/units/model/User/lifecycle.mmd?event=update' }

  def build(text = "flowchart LR\n  a --> b", **options)
    described_class.build(text, name: 'User lifecycle update', focus_url: view_url, generation: 7, mmd_url: mmd,
                                **options)
  end

  it 'fences the text as mermaid, then links the view and its .mmd text on one line naming the generation' do
    expect(build.body).to eq(<<~MARKDOWN)
      ```mermaid
      flowchart LR
        a --> b
      ```
      [Woods Map, User lifecycle update, gen 7](#{view_url}) · [Mermaid text](#{mmd})
    MARKDOWN
  end

  it 'keeps the text byte for byte, a trailing newline aside' do
    text = "sequenceDiagram\n  participant A as \"Ünïcode · <b>\"\n"
    expect(build(text).body).to start_with("```mermaid\n#{text}```\n")
  end

  it 'links only the view when there is no .mmd URL' do
    body = described_class.build('erDiagram', name: 'x', focus_url: view_url, generation: 7).body
    expect(body.lines.last).to eq("[Woods Map, x, gen 7](#{view_url})\n")
  end

  it 'opens a longer fence than any run of backticks in the text, so the text cannot close it' do
    body = build("flowchart LR\n  a[\"`**md** ````x`\"]").body
    expect(body).to start_with("`````mermaid\n").and include("\n`````\n")
  end

  it 'escapes the label and encodes what would end the link destination' do
    body = described_class.build('erDiagram', name: 'Blog "main" <b>[x]_*', generation: nil,
                                              focus_url: 'https://h/woods/units/model/A (b)/schema').body
    expect(body.lines.last).to eq("[Woods Map, Blog \"main\" \\<b\\>\\[x\\]\\_\\*](https://h/woods/units/model/A%20%28b%29/schema)\n")
  end

  it 'refuses a comment longer than GitHub holds with its length, never a cut fence' do
    fits = build('x' * (described_class::LIMIT - build('').length))
    expect([fits.body.length, fits.refusal]).to eq([described_class::LIMIT, nil])
    over = build('x' * (described_class::LIMIT - build('').length + 1))
    expect([over.body, over.length]).to eq([nil, described_class::LIMIT + 1])
    expect(over.refusal).to eq('Too long for a GitHub comment: 65,537 characters, over its limit of 65,536. ' \
                               'Share the .mmd URL instead.')
    expect(over.short_refusal).to eq('too long for a PR comment (65,537 of 65,536 characters)')
  end
end
