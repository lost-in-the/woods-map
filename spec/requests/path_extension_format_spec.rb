# frozen_string_literal: true

# Unit identifiers and file paths keep their extensions (config/database.yml,
# locales/en.yml, app/javascript/x.js). The routes declare format: false, but
# without an Accept header Rails still reads the format from the path's
# extension, so a crawler, a smoke script or curl -H 'Accept:' asked for a
# YAML template that does not exist and got a 500.
RSpec.describe 'Path extensions on unit and file routes', type: :request do
  let(:no_accept) { { 'HTTP_ACCEPT' => '' } }

  it 'renders the HTML not-found page for a unit whose identifier ends in .yml' do
    get '/woods/units/config_file/config/missing.yml', headers: no_accept
    expect(response).to have_http_status(:not_found)
    expect(response.media_type).to eq('text/html')
  end

  it 'renders HTML for a tab of such a unit and for a file path ending in .json' do
    get '/woods/units/i18n/missing.yml/history', headers: no_accept
    expect(response.media_type).to eq('text/html')
    get '/woods/files/config/missing.json', headers: no_accept
    expect(response.media_type).to eq('text/html')
  end

  it 'leaves a request with an Accept header to content negotiation' do
    get '/woods/units/config_file/config/missing.yml', headers: { 'HTTP_ACCEPT' => 'text/html' }
    expect(response).to have_http_status(:not_found)
  end
end
