# frozen_string_literal: true

RSpec.describe WoodsMap::ApplicationHelper, type: :helper do
  it 'is the absolute address with its query, never carrying a token (E-6, D-4)' do
    controller.request = ActionDispatch::TestRequest.create(
      'HTTP_HOST' => 'map.example', 'PATH_INFO' => '/woods/units/controller/UsersController/passage',
      'QUERY_STRING' => 'token=secret&action_name=edit&event=update'
    )
    expect(helper.focus_url)
      .to eq('http://map.example/woods/units/controller/UsersController/passage?action_name=edit&event=update')
  end

  it 'has no query mark when the page has no query' do
    controller.request = ActionDispatch::TestRequest.create('HTTP_HOST' => 'map.example', 'PATH_INFO' => '/woods/units',
                                                            'QUERY_STRING' => 'token=secret')
    expect(helper.focus_url).to eq('http://map.example/woods/units')
  end
end
