# frozen_string_literal: true

# The Passage tab over the resolved filter chain (W-8, woods#758), and its
# fallback to declared scopes on a generation published before it.
RSpec.describe 'The filter chain on the Passage tab', type: :request do
  context 'with the resolved chain' do
    def resolve(unit)
      unit = unit.deep_dup
      filters = unit['metadata']['filters']
      filters.each do |f|
        f.merge!('owner' => 'ActionController::Base', 'applies_to' => unit['metadata']['actions'],
                 'applicability' => 'resolved')
      end
      apps = filters.select { |f| f['file'] }
      apps[0].merge!('owner' => 'UsersController', 'applies_to' => %w[edit update])
      apps[1].merge!('owner' => 'Authenticating', 'applies_to' => %w[create edit], 'applicability' => 'conditional',
                     'unless' => ':api_request?')
      apps[2].merge!('owner' => 'MicropostsController', 'applies_to' => [])
      unit
    end

    before do
      allow(WoodsMap::Repository).to receive(:open).and_wrap_original do |open, *args, &block|
        open.call(*args) do |repository|
          allow(repository).to receive(:unit).and_wrap_original do |unit, identifier, **options|
            found = unit.call(identifier, **options)
            identifier == 'UsersController' && found ? resolve(found) : found
          end
          allow(repository).to receive(:identifier_types).and_wrap_original do |types, identifier|
            identifier == 'Authenticating' ? ['concern'] : types.call(identifier)
          end
          # A link needs the typed unit in the generation, not only its type name.
          allow(repository).to receive(:graph_node).and_wrap_original do |node, identifier, **options|
            identifier == 'Authenticating' ? { 'type' => 'concern' } : node.call(identifier, **options)
          end
          block.call(repository)
        end
      end
      get '/woods/units/controller/UsersController/passage?action_name=edit'
    end

    it 'draws the matrix in chain order with the resolved actions' do
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Filter matrix <span class="n">chain order</span>', '>filter, owner</th>')
      expect(response.body[%r{admin_user</a>.*?</tr>}m]).not_to include('✓')
    end

    it 'links each other owner the index holds, marks a concern and names the controller itself plainly' do
      expect(response.body).to include('← <a href="/woods/units/concern/Authenticating">Authenticating</a>',
                                       '<a href="/woods/units/controller/MicropostsController">',
                                       '<span class="mut regular">UsersController</span>')
    end

    it 'marks a conditional filter as such and never claims its condition resolves' do
      expect(response.body).to include(', conditional: unless: :api_request?')
      expect(response.body).to include('title="unless: :api_request?; only: edit, update"')
      expect(response.body).to include('<span class="sr-only">, when unless: :api_request?</span>')
      expect(response.body).to include('conditional, not evaluated')
    end

    it 'counts applying filters from the resolved chain and labels the rest skipped' do
      expect(response.body).to include('Filters, 2 of 3 apply', 'resolved chain, W-8')
      expect(response.body).to include('<span>skipped</span><span>admin_user, only: destroy, from ')
      expect(response.body).to include('filter if/unless conditions are not evaluated')
      expect(response.body).not_to include('W-8, re-extract', 'declared scope')
    end
  end

  context 'without the resolved chain in the generation' do
    before { get '/woods/units/controller/UsersController/passage?action_name=edit' }

    it 'keeps the declared matrix' do
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Filter matrix <span class="n">declared scope</span>',
                                       '>filter, declared in</th>', 'Filters, 2 of 3 declared')
      expect(response.body).not_to include('chain order', 'conditional, not evaluated')
    end

    it 'names the resolved chain as a limit' do
      expect(response.body).to include('this generation has no resolved chain (W-8)', 'W-8, re-extract',
                                       'resolved filter chain and owners, not in this generation')
    end
  end
end
