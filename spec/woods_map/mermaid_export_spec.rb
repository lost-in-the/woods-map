# frozen_string_literal: true

RSpec.describe WoodsMap::MermaidExport do
  it 'names the file after what the diagram shows, safe for any file system' do
    expect(described_class.filename('Admin::User lifecycle create')).to eq('admin-user-lifecycle-create.mmd')
    expect(described_class.filename('GET /users/:id passage')).to eq('get-users-id-passage.mmd')
    expect(described_class.filename('')).to eq('diagram.mmd')
    expect(described_class.filename('x' * 200).length).to eq(84)
  end

  it 'marks only diagram types newer than GitHub\'s Mermaid' do
    expect(described_class).to be_newer_than_github("swimlane-beta TB\n  subgraph a [A]\n  end")
    %w[erDiagram sequenceDiagram stateDiagram-v2].push('flowchart LR').each do |start|
      expect(described_class).not_to be_newer_than_github("#{start}\n  x")
    end
  end
end
