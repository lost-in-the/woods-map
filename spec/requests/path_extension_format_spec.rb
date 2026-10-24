# frozen_string_literal: true

require_relative '../support/synthetic_index'

# Unit identifiers and file paths keep their extension in the URL. Rails reads
# a format from a path extension whenever the Accept header is a browser's
# catch-all, so before the fix `config/cable.yml` answered 500 (no YAML
# template) and `app/javascript/application.js` rendered without the layout:
# no stylesheet, no import map, a page that never starts.
RSpec.describe 'Pages for paths whose extension Rails knows as a format', type: :request do
  include WoodsMap::SyntheticIndex

  let(:browser) { { 'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' } }
  let(:root) { Pathname.new(Dir.mktmpdir('map-path-extension')) }

  before do
    write_synthetic_index(root, {
                            'config_files' => [{ 'identifier' => 'config/cable.yml', 'type' => 'config_file',
                                                 'file_path' => 'config/cable.yml',
                                                 'source_code' => "development:\n  adapter: async\n" }],
                            'js_modules' => [{ 'identifier' => 'app/javascript/application.js', 'type' => 'js_module',
                                               'file_path' => 'app/javascript/application.js',
                                               'source_code' => "import \"controllers\"\n" }],
                            'i18n' => [{ 'identifier' => 'en.json', 'type' => 'i18n',
                                         'file_path' => 'config/locales/en.json', 'source_code' => "{}\n" }]
                          })
    WoodsMap.configuration.index_dir = root
    WoodsMap::FileTree.reset!
  end

  after do
    WoodsMap::FileTree.reset!
    FileUtils.remove_entry(root)
  end

  def expect_full_page
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('text/html')
    expect(response.body).to include('<script type="importmap"', 'woods_map/map.css')
  end

  {
    '/woods/units/config_file/config/cable.yml' => 'a YAML unit',
    '/woods/units/js_module/app/javascript/application.js' => 'a JavaScript unit',
    '/woods/units/i18n/en.json' => 'a JSON unit',
    '/woods/files/config/cable.yml' => 'a YAML file page',
    '/woods/files/app/javascript/application.js' => 'a JavaScript file page'
  }.each do |path, what|
    it "renders #{what} as a full HTML page for a browser" do
      get path, headers: browser
      expect_full_page
    end
  end

  it 'follows a lens switch back to the full page' do
    get '/woods/units/config_file/config/cable.yml?lens=written', headers: browser
    expect(response).to redirect_to('/woods/units/config_file/config/cable.yml')
    get response.location, headers: browser
    expect_full_page
  end

  it 'keeps the 404 page HTML for a missing unit with such an extension' do
    get '/woods/units/config_file/config/missing.yml', headers: browser
    expect(response).to have_http_status(:not_found)
    expect(response.media_type).to eq('text/html')
  end
end
