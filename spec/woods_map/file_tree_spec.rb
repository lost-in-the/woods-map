# frozen_string_literal: true

RSpec.describe WoodsMap::FileTree do
  let(:tree) do
    described_class.new({ 'app/models/user.rb' => ['User'], 'app/models/post.rb' => %w[Post Post::Draft],
                          'app/controllers/users_controller.rb' => ['UsersController'] },
                        { 'User' => { 'type' => 'model' }, 'Post' => { 'type' => 'model' },
                          'UsersController' => { 'type' => 'controller' } })
  end

  it 'lists directories as on disk with the units beneath them, then files' do
    expected = [[:dir, 'app', 0], [:dir, 'controllers', 1], [:file, 'users_controller.rb', 2],
                [:dir, 'models', 1], [:file, 'post.rb', 2], [:file, 'user.rb', 2]]
    expect(tree.rows.map { |r| [r.kind, r.name, r.level] }).to eq(expected)
    expect(tree.rows.first.count).to eq(4)
  end

  it 'links a file to its first unit and knows how many it holds' do
    post = tree.rows.find { |r| r.name == 'post.rb' }
    expect(post.identifier).to eq('Post')
    expect(post.type).to eq('model')
    expect(post.units).to eq(2)
    expect(tree.unit_count).to eq(4)
  end

  it 'is cached per generation' do
    described_class.reset!
    WoodsMap::Repository.open(FIXTURE_INDEX) do |repository|
      expect(described_class.for(repository)).to equal(described_class.for(repository))
    end
  end
end
