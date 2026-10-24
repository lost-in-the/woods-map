# frozen_string_literal: true

require_relative '../support/range_report_fixture'

# The page keys (keys_controller) listen on the document, so one mount per
# page serves every key. A second mount on an inner element ran each key's
# handler twice; y only wrote once because the first handler marked the
# event handled.
RSpec.describe 'The page keys controller', type: :request do
  include RangeReportFixture

  {
    'a unit page' => ['/woods/units/model/User', {}],
    'the Lifecycle tab' => ['/woods/units/model/User/lifecycle', {}],
    'the Passage tab' => ['/woods/units/controller/UsersController/passage', { action_name: 'edit' }],
    'the pre-change impact page' => ['/woods/impact', { focus: 'User' }],
    'a range impact page' => ['/woods/impact', { from: 'gen:1', lens: 'changed' }],
    'the ERD' => ['/woods/erd', {}],
    'the History tab' => ['/woods/units/model/User/history', {}]
  }.each do |page, (path, params)|
    it "mounts once on #{page}, on the body" do
      stub_range_report
      get path, params: params
      expect(response).to have_http_status(:ok)
      mounts = response.parsed_body.css('[data-controller]').select do |node|
        node['data-controller'].split.include?('keys')
      end
      expect(mounts.map(&:name)).to eq(['body'])
    end
  end
end
