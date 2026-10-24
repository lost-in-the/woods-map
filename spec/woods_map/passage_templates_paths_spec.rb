# frozen_string_literal: true

# The template index answers what a scan of the graph's view templates did:
# the template itself, or one with extensions after the path in the same
# directory, never one in a subdirectory.
RSpec.describe WoodsMap::PassageTemplates do
  let(:ids) do
    %w[widgets/show.html.erb widgets/show.json.jbuilder widgets/show widgets/_row.html.erb widgets/show/extra.html.erb
       widgets/showcase.html.erb v1.2/widgets/index.html.erb layouts/application.html.erb widgets/trailing.]
  end

  def scanned(path)
    prefix = "#{path}."
    ids.select { |id| id == path || (id.start_with?(prefix) && id.delete_prefix(prefix).exclude?('/')) }.sort
  end

  it 'names the same templates as a scan, for every path an action can render' do
    paths = %w[widgets/show widgets/show.html widgets/show.html.erb widgets/_row widgets/show/extra widgets/showcase
               v1 v1.2/widgets/index layouts/application widgets/trailing widgets missing/path]
    index = described_class.template_paths(ids)

    paths.each { |path| expect(Array(index[path]).sort).to eq(scanned(path)), path }
  end

  it 'builds the index once per template list' do
    allow(described_class).to receive(:build_template_paths).and_call_original
    2.times { described_class.template_paths(ids) }

    expect(described_class).to have_received(:build_template_paths).once
  end
end
