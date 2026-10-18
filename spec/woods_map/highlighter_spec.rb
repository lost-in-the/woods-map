# frozen_string_literal: true

RSpec.describe WoodsMap::Highlighter do
  it 'highlights Ruby onto the code-view classes, one line each' do
    lines = described_class.lines("class Post < ApplicationRecord\n  # a comment\n  validates :title\nend\n")
    expect(lines.size).to eq(4)
    expect(lines[0]).to include('<span class="k">class</span>').and include('<span class="const">Post</span>')
    expect(lines[1]).to include('<span class="cm"># a comment</span>')
    expect(lines[2]).to include('<span class="str">:title</span>')
  end

  it 'escapes HTML and keeps unknown languages plain' do
    expect(described_class.lines('<b>', language: 'text')).to eq(['&lt;b&gt;'])
    expect(described_class.lines("x = '<b>'", language: 'ruby').first).to include('&lt;b&gt;')
  end

  it 'picks the lexer from the file extension' do
    expect(described_class.language_for('app/views/users/show.html.erb')).to eq('erb')
    expect(described_class.language_for('app/models/user.rb')).to eq('ruby')
  end
end
