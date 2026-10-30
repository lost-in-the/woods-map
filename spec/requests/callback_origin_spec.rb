# frozen_string_literal: true

# The Lifecycle and Passage tabs over the callback and filter `origin` Woods
# publishes (woods#936), and the inference they keep on a generation without it.
RSpec.describe 'Callback origin on the Lifecycle and Passage tabs', type: :request do
  def with_origin(unit)
    unit = unit.deep_dup
    metadata = unit['metadata']
    Array(metadata['callbacks']).each do |cb|
      cb['origin'] = %w[downcase_email create_activation_digest].include?(cb['filter']) ? 'app' : 'framework'
    end
    Array(metadata['callbacks']) << { 'type' => 'before_create', 'filter' => 'generate_confirmation_token',
                                      'kind' => 'before', 'conditions' => {}, 'origin' => 'gem' }
    Array(metadata['filters']).each { |f| f['origin'] = f['file'] ? 'app' : 'framework' }
    Array(metadata['filters']) << { 'kind' => 'before', 'filter' => 'authenticate_user!', 'origin' => 'gem' }
    unit
  end

  def publish_origin
    allow(WoodsMap::Repository).to receive(:open).and_wrap_original do |open, *args, &block|
      open.call(*args) do |repository|
        allow(repository).to receive(:unit).and_wrap_original do |unit, identifier, **options|
          found = unit.call(identifier, **options)
          %w[User UsersController].include?(identifier) && found ? with_origin(found) : found
        end
        block.call(repository)
      end
    end
  end

  context 'with origin published' do
    before { publish_origin }

    it 'counts the Lifecycle tab\'s hidden callbacks by who wrote them, a gem apart from the framework' do
      get '/woods/units/model/User/lifecycle'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('16 framework callbacks hidden', '1 gem callback hidden')
      expect(response.body).not_to include('no callback origin')
    end

    it 'lists a gem filter on the Passage as a gem\'s and hides the framework ones' do
      get '/woods/units/controller/UsersController/passage?action_name=edit'
      expect(response).to have_http_status(:ok)
      row = html_response_document.css('.rows > div').find { |d| d.text.include?('authenticate_user!') }
      expect(row.text.squish).to include('authenticate_user!').and include('gem')
      expect(response.body).to include('4 hidden (Rails filters and procs)')
      expect(response.body).not_to include('no filter origin')
    end
  end

  context 'without origin' do
    it 'keeps the Lifecycle tab\'s inference and names the limit' do
      get '/woods/units/model/User/lifecycle'
      expect(response.body).to include('2 framework callbacks hidden', 'no callback origin')
    end

    it 'keeps the Passage\'s inference by name and names the limit' do
      get '/woods/units/controller/UsersController/passage?action_name=edit'
      expect(response.body).to include('4 hidden (CSRF, origin, engine procs)', 'no filter origin')
    end
  end
end
