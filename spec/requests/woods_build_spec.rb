# frozen_string_literal: true

RSpec.describe 'Index build compatibility', type: :request do
  let(:index) { Woods::PublishedIndex.new(Pathname.new(FIXTURE_INDEX)) }

  before do
    WoodsMap::Erd.reset!
    allow(Woods::PublishedIndex).to receive(:open).and_yield(index)
  end

  def writer(version: '2.1.0', revision: nil, branch: 'release')
    allow(index).to receive(:manifest).and_wrap_original do |original|
      original.call.merge('woods_version' => version, 'woods_revision' => revision, 'git_branch' => branch)
    end
  end

  it 'warns without refusing a readable older generation' do
    writer
    get '/woods/units'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Index written by Woods 2.1.0', 'this reader is 2.2.0.alpha')
  end

  it 'does not warn for the same version without a revision' do
    get '/woods'
    expect(response.body).not_to include('Index written by')
  end

  it 'warns for different revisions of the same version' do
    writer(version: '2.2.0.alpha', revision: 'a' * 40)
    stub_woods_build(revision: 'b' * 40)
    get '/woods'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('different Woods build', 'build_mismatch')
  end

  %i[unit units].each do |read|
    it "explains a failing #{read} read with a 503 panel" do
      writer
      allow(index).to receive(read).and_raise(IOError, 'private payload detail')
      get(read == :unit ? '/woods/units/model/User' : '/woods/erd')
      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).to include('Index could not be read', '2.1.0', '2.2.0.alpha', 'woods:extract')
      expect(response.body).not_to include('private payload detail')
    end
  end

  it 'uses corrupt-index wording for a matching reader' do
    allow(index).to receive(:unit).and_raise(IOError)
    get '/woods/units/model/User'
    expect(response).to have_http_status(:service_unavailable)
    expect(response.body).to include('corrupt or incomplete')
    expect(response.body).not_to include('Index written by')
  end

  it 'escapes writer markup in the banner and panel' do
    writer(version: '<script>writer</script>')
    get '/woods/units'
    expect(response.body).to include('&lt;script&gt;writer&lt;/script&gt;')
    allow(index).to receive(:unit).and_raise(IOError)
    get '/woods/units/model/User'
    expect(response.body).to include('&lt;script&gt;writer&lt;/script&gt;')
    expect(response.body).not_to include('<script>writer</script>')
  end

  it 'shows the published branch and names an absent branch' do
    writer
    get '/woods/units'
    expect(response.body).to include('release')
    writer(branch: nil)
    get '/woods/units'
    expect(response.body).to include('branch not recorded')
  end

  it 'keeps Mermaid failures plain text' do
    writer
    allow(index).to receive(:units).and_raise(IOError)
    get '/woods/erd.mmd'
    expect(response).to have_http_status(:service_unavailable)
    expect(response.media_type).to eq('text/plain')
  end

  it 'keeps the palette JSON refusal shape on a typed read failure' do
    allow(index).to receive(:unit).and_raise(IOError)
    allow(WoodsMap::Palette).to receive(:new).and_wrap_original do |original, repository, query|
      repository.unit('User', type: 'model')
      original.call(repository, query)
    end
    get '/woods/search/palette', params: { q: 'User' }
    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body).to include('groups' => [], 'complete' => false)
  end

  it 'keeps neighbourhood refusals JSON on a typed read failure' do
    writer
    allow(index).to receive(:unit).and_raise(IOError)
    allow(WoodsMap::NeighbourhoodResponse).to receive(:new).and_wrap_original do |original, repository, query|
      repository.unit('User', type: 'model')
      original.call(repository, query)
    end
    get '/woods/graph/neighbourhood', params: { centre: 'User', type: 'model' }
    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body).to include('error' => 'index_unavailable', 'message' => include('2.1.0'))
  end

  it 'keeps guide refusals JSON on a typed context read failure' do
    WoodsMap.configuration.guide_enabled = true
    WoodsMap.configuration.guide_chats_dir = Dir.mktmpdir('woods-build-guide')
    WoodsMap.configuration.guide_chat_factory = -> { WoodsMap::FakeGuideChat.new([]) }
    allow(index).to receive(:unit).and_raise(IOError)
    post '/woods/guide/questions', params: { question: 'What is User?',
                                             context: { page: 'code', type: 'model', identifier: 'User' } }
    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body).to include('error' => 'index_unavailable')
  ensure
    FileUtils.remove_entry(WoodsMap.configuration.guide_chats_dir)
  end
end
