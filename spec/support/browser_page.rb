# frozen_string_literal: true

require 'base64'
require 'open3'
require 'tmpdir'

module WoodsMap
  # A page the engine rendered, run in headless Chromium at one window size
  # with the shipped stylesheets, the vendored Stimulus and the engine's own
  # controllers (a page opened from a file cannot fetch modules beside it, so
  # each module is a data URL in the import map). Requests the page makes are
  # answered from +fetches+ (URL fragment => body). The +runner+ is a module
  # body that may await; it ends by calling report(result).
  module BrowserPage
    CONTROLLERS = %w[cliff tooltip rows tree sheet copy share palette peek card trail keys help settings
                     disambiguation pinboard brush matrix].freeze

    # @param html [String] a full page from a request
    # @return [Hash] the runner's report
    def run_page(html, runner:, width: 1440, height: 900, fetches: {})
      Dir.mktmpdir('woods-map-page') do |directory|
        fixture = File.join(directory, 'page.html')
        File.write(fixture, page_fixture(html, runner, fetches))
        output, error, status = Open3.capture3(
          ENV.fetch('WOODS_MAP_BROWSER'), '--headless', '--disable-gpu', '--disable-background-networking',
          '--no-first-run', '--virtual-time-budget=10000', "--window-size=#{width},#{height}",
          "--user-data-dir=#{File.join(directory, 'profile')}", '--dump-dom', "file://#{fixture}"
        )
        result = Nokogiri::HTML(output).at_css('#wm-result')
        unless status.success? && result && !result.text.empty?
          raise "Page regression did not produce results: #{error}"
        end

        JSON.parse(result.text).tap { |report| raise report['error'] if report.is_a?(Hash) && report['error'] }
      end
    end

    private

    def page_fixture(html, runner, fetches)
      body = Nokogiri::HTML(html).at_css('body')
      attributes = body.attributes.map { |name, value| %(#{name}="#{ERB::Util.html_escape(value.value)}") }.join(' ')
      "<!doctype html><html lang=\"en\" class=\"js\"><head><meta charset=\"utf-8\"><style>#{page_styles}</style>" \
        "<script type=\"importmap\">#{JSON.generate(imports: page_imports)}</script></head>" \
        "<body #{attributes}>#{body.inner_html}<pre id=\"wm-result\" hidden></pre>" \
        "<script type=\"module\">#{page_boot(fetches)}\n#{runner}</script></body></html>"
    end

    def page_root = File.expand_path('../..', __dir__)

    def page_styles
      %w[tokens.css map.css].map do |name|
        File.read(File.join(page_root, 'app/assets/stylesheets/woods_map', name))
      end.join("\n")
    end

    def page_imports
      data = lambda do |path|
        "data:text/javascript;base64,#{Base64.strict_encode64(File.read(File.join(page_root, path)))}"
      end
      controllers = CONTROLLERS.to_h do |name|
        ["wm/#{name}", data.call("app/javascript/woods_map/controllers/#{name}_controller.js")]
      end
      controllers.merge('@hotwired/stimulus' => data.call('vendor/javascript/stimulus.js'))
    end

    def page_boot(fetches)
      imports = CONTROLLERS.map { |name| "import C_#{name} from \"wm/#{name}\"" }.join("\n")
      registers = CONTROLLERS.map { |name| "application.register(#{name.to_json}, C_#{name})" }.join("\n")
      <<~JS
        import { Application } from "@hotwired/stimulus"
        #{imports}
        const answers = #{JSON.generate(fetches).gsub('</', '<\\/')}
        window.fetch = async (url) => {
          const key = Object.keys(answers).find((fragment) => String(url).includes(fragment))
          return key ? new Response(answers[key], { status: 200, headers: { "Content-Type": "text/html" } }) : new Response("", { status: 404 })
        }
        const application = Application.start()
        #{registers}
        const settle = (ms = 50) => new Promise((resolve) => setTimeout(resolve, ms))
        const report = (result) => { document.getElementById("wm-result").textContent = JSON.stringify(result) }
        const shown = (el) => !!el && el.getClientRects().length > 0 && getComputedStyle(el).visibility !== "hidden"
        const key = (target, init) => { const event = new KeyboardEvent("keydown", { bubbles: true, cancelable: true, ...init }); target.dispatchEvent(event); return event }
        window.addEventListener("error", (event) => report({ error: String(event.message) }))
        window.addEventListener("unhandledrejection", (event) => report({ error: String(event.reason && event.reason.stack || event.reason) }))
        await settle()
      JS
    end
  end
end
