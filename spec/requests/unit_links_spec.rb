# frozen_string_literal: true

require_relative '../support/synthetic_index'

# Found by the mounted end-to-end sweep: every Rails app has the root route,
# whose identifier `GET /` ends in a slash that routing drops, and unit
# dependencies name things the index never extracted (framework classes,
# engine controllers, unmigrated tables, the `framework` and `view` types).
RSpec.describe 'Links between unit pages', type: :request do
  include WoodsMap::SyntheticIndex

  let(:root) { Pathname.new(Dir.mktmpdir('map-unit-links')) }
  let(:home) do
    { 'identifier' => 'GET /', 'type' => 'route', 'file_path' => 'config/routes.rb',
      'metadata' => { 'controller' => 'pages', 'action' => 'home' },
      'dependencies' => [{ 'target' => 'PagesController', 'type' => 'controller', 'via' => 'route' }] }
  end
  let(:pages) do
    { 'identifier' => 'PagesController', 'type' => 'controller', 'file_path' => 'app/controllers/pages_controller.rb',
      'source_code' => "class PagesController < ApplicationController\n  def home; end\nend\n",
      'dependencies' => [{ 'target' => 'pages/home', 'type' => 'view', 'via' => 'render' },
                         { 'target' => 'ActionCable', 'type' => 'framework', 'via' => 'reference' },
                         { 'target' => 'Rails::WelcomeController', 'type' => 'controller', 'via' => 'reference' },
                         { 'target' => 'GET /', 'type' => 'route', 'via' => 'route' }] }
  end

  before do
    write_synthetic_index(root, 'routes' => [home], 'controllers' => [pages])
    WoodsMap.configuration.index_dir = root
    WoodsMap::FileTree.reset!
  end

  after do
    WoodsMap::FileTree.reset!
    FileUtils.remove_entry(root)
  end

  describe 'a unit whose identifier ends in a slash' do
    %w[/woods/units/route/GET%20/ /woods/units/route/GET%20//graph /woods/units/route/GET%20//history].each do |path|
      it "opens #{path}" do
        get path
        expect(response).to have_http_status(:ok)
        expect(html_response_document.at_css('h1').text).to start_with('GET /')
      end
    end

    it 'serves its graph as Mermaid text' do
      get '/woods/units/route/GET%20//graph.mmd'
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/plain')
    end

    it 'keeps the slash through the lens redirect' do
      get '/woods/units/route/GET%20/?lens=written'
      expect(response).to redirect_to('/woods/units/route/GET%20/')
    end

    it 'is linked from the units index to a page that opens' do
      get '/woods/units'
      href = html_response_document.css('a').pluck('href').find { |h| h.start_with?('/woods/units/route/') }
      get href
      expect(response).to have_http_status(:ok)
    end

    it 'still finds a unit a reader typed with a trailing slash' do
      get '/woods/units/controller/PagesController/'
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'the facts tiles' do
    before { get '/woods/units/controller/PagesController' }

    it 'links a dependency the generation holds' do
      expect(html_response_document.css('a').pluck('href')).to include('/woods/units/route/GET%20/')
    end

    it 'names, without a link, what the index never extracted' do
      hrefs = html_response_document.css('a').pluck('href')
      expect(hrefs).not_to include('/woods/units/view/pages/home', '/woods/units/framework/ActionCable',
                                   '/woods/units/controller/Rails::WelcomeController')
      expect(response.body).to include('pages/home', 'ActionCable', 'Rails::WelcomeController')
    end
  end
end
