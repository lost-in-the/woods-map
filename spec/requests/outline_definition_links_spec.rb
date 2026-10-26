# frozen_string_literal: true

require_relative '../support/code_navigation_index'

RSpec.describe 'Controller outline definition links', type: :request do
  let(:rail) do
    get '/woods/units/controller/UsersController?lens=written'
    follow_redirect! if response.redirect?
    response.parsed_body.css('nav.rail')
  end

  it 'links each action to the line its published source names' do
    links = rail.css('li a').to_h { |a| [a.text.strip, a['href']] }
    expect(links).to include('create' => '#L20', 'show' => '#L11', 'index' => '#L7')
  end

  it 'links a filter to the line that declares it and keeps its scope text' do
    item = rail.css('li').find { |li| li.text.squish.include?('logged_in_user') }
    expect(item.at_css('a')['href']).to eq('#L2')
    expect(item.text.squish).to include('only destroy, edit, followers, following, index, update')
  end

  it 'leaves a filter with no published declaration line as text' do
    item = rail.css('li').find { |li| li.text.squish.include?('verify_authenticity_token') }
    expect(item.at_css('a')).to be_nil
  end

  describe 'with an action defined in another indexed file' do
    include CodeNavigationIndex

    before do
      controller = nav_unit('PostsController', 'controller', 'app/controllers/posts_controller.rb',
                            "class PostsController < BaseController\n  def show\n  end\nend\n",
                            'actions' => %w[show archive],
                            'action_sources' => {
                              'show' => { 'file' => 'app/controllers/posts_controller.rb', 'line' => 2 },
                              'archive' => { 'file' => 'app/controllers/base_controller.rb', 'line' => 9 }
                            })
      base = nav_unit('BaseController', 'controller', 'app/controllers/base_controller.rb')
      CodeNavigationIndex::Writer.write_navigation_generation(code_navigation_root, callers + [controller, base])
      graph = code_navigation_root.join('payloads/gen-1/dependency_graph.json')
      body = JSON.parse(graph.read)
      body['file_map'] = { 'app/controllers/base_controller.rb' => ['BaseController'],
                           'app/controllers/posts_controller.rb' => ['PostsController'] }
      graph.write(JSON.generate(body))
    end

    it 'links an inherited action to its owner and leaves an unmapped one as text' do
      get '/woods/units/controller/PostsController?lens=written'
      links = response.parsed_body.css('nav.rail li a').to_h { |a| [a.text.strip, a['href']] }
      expect(links).to include('show' => '#L2', 'archive' => '/woods/units/controller/BaseController#L9')
    end
  end
end
