# frozen_string_literal: true

require 'net/http'
require 'socket'

# The M8 gate on a real socket: the dummy host booted under Puma, bound to
# every interface, and driven over loopback and over a non-loopback address
# of this machine, so `REMOTE_ADDR` is what Puma saw rather than what a
# request spec claims. Tagged and excluded by default (it binds a port);
# opt in with:
#
#   WOODS_MAP_RUN_HTTP_SERVER=1 bin/rspec spec/woods_map/engine_http_server_spec.rb
module WoodsMapPuma
  # The dummy host under Puma on an ephemeral port of every interface,
  # started once for the file and stopped at exit.
  #
  # @return [Integer] the bound port
  def self.port
    @port ||= begin
      require 'puma'
      require 'puma/server'
      options = { min_threads: 1, max_threads: 4 }
      options[:log_writer] = Puma::LogWriter.null if defined?(Puma::LogWriter)
      events = defined?(Puma::LogWriter) ? nil : Puma::Events.strings
      server = Puma::Server.new(Rails.application, events, options)
      bound = server.add_tcp_listener('0.0.0.0', 0).addr[1]
      server.run
      at_exit { server.stop(true) }
      bound
    end
  end
end

RSpec.describe WoodsMap::Engine, :http_server do
  let(:port) { WoodsMapPuma.port }

  # An address of this machine that is not loopback, so the map sees a remote client.
  let(:remote_ip) do
    address = Socket.ip_address_list.find { |a| a.ipv4? && !a.ipv4_loopback? && !a.ipv4_multicast? }
    skip('no non-loopback IPv4 address on this machine') unless address
    address.ip_address
  end

  def request(verb, ip, path, headers: {}, form: nil)
    Net::HTTP.start(ip, port, open_timeout: 5, read_timeout: 30) do |http|
      klass = { get: Net::HTTP::Get, post: Net::HTTP::Post, delete: Net::HTTP::Delete }.fetch(verb)
      message = klass.new(path, { 'Accept' => 'text/html' }.merge(headers))
      message.set_form_data(form) if form
      http.request(message)
    end
  end

  context 'without a token' do
    it 'serves loopback, with the engine policy on the response' do
      response = request(:get, '127.0.0.1', '/woods')
      expect(response.code).to eq('200')
      expect(response['Content-Security-Policy']).to include("script-src http://127.0.0.1:#{port}/woods/assets/")
        .and include("frame-ancestors 'none'")
    end

    it 'refuses a non-loopback client with the plain 403 panel and nothing from the index' do
      response = request(:get, remote_ip, '/woods')
      expect(response.code).to eq('403')
      expect(response.body).to include('Woods Map refused the request').and include('WOODS_MAP_TOKEN')
      expect(response.body).not_to include('gen ')
      expect(response['Content-Security-Policy']).to include("default-src 'none'")
    end

    it 'refuses a loopback connection that names another host (DNS rebinding)' do
      response = request(:get, '127.0.0.1', '/woods', headers: { 'Host' => "rebound.example:#{port}" })
      expect(response.code).to eq('403')
      expect(response.body).to include('DNS-rebinding')
    end
  end

  context 'with a token' do
    before { WoodsMap.configuration.token = 'puma-token' }

    let(:origin) { "http://#{remote_ip}:#{port}" }

    it 'sends a browser without credentials to the token form and serves a bearer' do
      response = request(:get, remote_ip, '/woods')
      expect(response.code).to eq('302')
      expect(response['Location']).to end_with('/woods/session/new')
      expect(request(:get, remote_ip, '/woods', headers: { 'Authorization' => 'Bearer puma-token' }).code).to eq('200')
    end

    it 'exchanges the token at the form from its own origin and then serves pages by cookie' do
      response = request(:post, remote_ip, '/woods/session', headers: { 'Origin' => origin },
                                                             form: { token: 'puma-token' })
      expect(response.code).to eq('302')
      cookie = response['Set-Cookie'].to_s
      expect(cookie).to include('woods_map_session=').and match(/httponly/i).and match(/samesite=strict/i)
      page = request(:get, remote_ip, '/woods', headers: { 'Cookie' => cookie.split(';').first })
      expect(page.code).to eq('200')
    end

    {
      'a foreign Origin' => { 'Origin' => 'https://evil.example' },
      'a foreign Referer' => { 'Referer' => 'https://evil.example/form' },
      'an opaque Origin' => { 'Origin' => 'null' },
      'a cross-site fetch' => { 'Sec-Fetch-Site' => 'cross-site' }
    }.each do |name, headers|
      it "refuses a session write with #{name}, even with the right token" do
        response = request(:post, remote_ip, '/woods/session', headers: headers, form: { token: 'puma-token' })
        expect(response.code).to eq('403')
        expect(response.body).to include('another origin')
        expect(response['Set-Cookie'].to_s).not_to include('woods_map_session=')
      end
    end

    it 'refuses a cross-origin sign-out' do
      response = request(:delete, remote_ip, '/woods/session',
                         headers: { 'Origin' => 'https://evil.example', 'Authorization' => 'Bearer puma-token' })
      expect(response.code).to eq('403')
    end
  end

  it 'answers 429 with Retry-After once a client spends the search budget' do
    WoodsMap.configuration.rate_limit = 2
    codes = Array.new(3) do
      request(:get, '127.0.0.1', '/woods/search/palette?q=User', headers: { 'Accept' => 'application/json' })
    end
    expect(codes.map(&:code)).to eq(%w[200 200 429])
    expect(codes.last['Retry-After'].to_i).to be_positive
  end
end
