# frozen_string_literal: true

RSpec.describe WoodsMap::Guide::Answer do
  let(:identifiers) { { 'Post' => 'model', 'NotifySubscribersJob' => 'job', 'Admin::Report' => 'model', 'users/show.html.erb' => 'view_template' } }
  let(:link) { ->(identifier, type) { "/woods/units/#{type}/#{identifier}" } }

  def html(markdown)
    described_class.new(markdown, identifiers: identifiers, link: link).to_html
  end

  it 'links identifiers the generation knows and leaves invented ones plain' do
    out = html('Post enqueues NotifySubscribersJob, not GhostJob.')
    expect(out).to include('<a href="/woods/units/model/Post">Post</a>')
      .and include('<a href="/woods/units/job/NotifySubscribersJob">NotifySubscribersJob</a>')
    expect(out).to include('GhostJob').and not_include('GhostJob</a>')
  end

  it 'links a method reference to its unit and namespaced constants whole' do
    expect(html('See Post#publish! and Admin::Report.'))
      .to include('<a href="/woods/units/model/Post">Post#publish!</a>')
      .and include('<a href="/woods/units/model/Admin::Report">Admin::Report</a>')
  end

  it 'links code spans that name a unit exactly, including non-constant identifiers' do
    expect(html('Renders `users/show.html.erb` and `@user`.'))
      .to include('<a href="/woods/units/view_template/users/show.html.erb"><code>users/show.html.erb</code></a>')
      .and include('<code>@user</code>')
  end

  it 'strips raw HTML and Markdown link targets so nothing else becomes a link' do
    out = html('<script>alert(1)</script><img src=x onerror=alert(1)> [click](https://evil.example) ' \
               '![i](x.png) <b>Post</b>')
    expect(out).to not_include('<script').and not_include('<img').and not_include('evil.example')
      .and not_include('onerror=')
    expect(out).to include('click').and include('<a href="/woods/units/model/Post">Post</a>')
  end

  it 'escapes what remains, inside code too' do
    expect(html('`<b>&` and 2 < 3')).to include('<code>&lt;b&gt;&amp;</code>').and include('2 &lt; 3')
  end

  it 'renders paragraphs, lists, headings, fenced code, bold and emphasis' do
    out = html("## Two ways\n\n1. **First** way\n   continues\n2. *Second*\n\n- a\n- b\n\n" \
               "```ruby\nPost.find(<id>)\n```\nlast")
    expect(out).to include('<p><b>Two ways</b></p>')
      .and include('<ol><li><b>First</b> way continues</li><li><em>Second</em></li></ol>')
      .and include('<ul><li>a</li><li>b</li></ul>')
      .and include('<pre class="cmd" tabindex="0">Post.find(&lt;id&gt;)</pre>')
      .and include('<p>last</p>')
  end
end
