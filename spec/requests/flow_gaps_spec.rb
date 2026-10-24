# frozen_string_literal: true

RSpec.describe 'Best-effort flow gaps (W-14)', type: :request do
  let(:failure) do
    { 'entry_point' => 'UsersController#show', 'controller' => 'UsersController', 'action' => 'show',
      'reason' => 'flow_assembly_error', 'error' => 'StandardError: cannot trace UsersController#show' }
  end

  before do
    allow_any_instance_of(WoodsMap::Repository).to receive(:flow_failures).and_return([failure]) # rubocop:disable RSpec/AnyInstance
  end

  it 'names the missing flow on the passage of that action' do
    get '/woods/units/controller/UsersController/passage?action_name=show'
    expect(response.body).to include('The precomputed flow of UsersController#show did not assemble',
                                     'cannot trace UsersController#show')
    get '/woods/units/controller/UsersController/passage?action_name=edit'
    expect(response.body).not_to include('did not assemble')
  end

  it 'lists the missing flows of the radius on Impact Flows' do
    get '/woods/impact', params: { focus: 'UsersController', lens: 'flows' }
    expect(response.body).to include('Flows not assembled', 'UsersController#show', 'flow_assembly_error')
    get '/woods/impact', params: { focus: 'Micropost', lens: 'flows', depth: 1 }
    expect(response.body).not_to include('Flows not assembled')
  end

  it 'reads no failures from a Woods that does not publish them' do
    allow_any_instance_of(WoodsMap::Repository).to receive(:flow_failures).and_call_original # rubocop:disable RSpec/AnyInstance
    WoodsMap::Repository.open(FIXTURE_INDEX) { |repository| expect(repository.flow_failures).to eq([]) }
  end
end
