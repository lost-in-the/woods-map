# frozen_string_literal: true

module WoodsMap
  # The guide's per-browser session: a signed, HttpOnly, SameSite=Strict
  # cookie holding an id the server generated, and the file store it names.
  # Also the guide's own gate, in front of the engine's: the guide answers
  # only when it is enabled and loadable, and never on a non-loopback request
  # without the token (M8, design study section 11).
  module GuideSession
    extend ActiveSupport::Concern

    COOKIE = 'woods_map_guide'

    included do
      before_action :require_guide!
    end

    private

    def require_guide!
      unless woods_map_config.token? || loopback_without_token?
        return render(json: { 'error' => 'forbidden', 'message' => 'The guide needs the token on this host.' },
                      status: :forbidden)
      end
      return if WoodsMap::Guide.status(woods_map_config) == :ready

      render json: { 'error' => 'guide_unavailable',
                     'message' => WoodsMap::Guide.notice(woods_map_config) || 'The guide is not enabled.' },
             status: :not_found
    end

    # @return [WoodsMap::Guide::Store]
    def guide_store
      id = cookies.signed[COOKIE].to_s
      unless id.match?(WoodsMap::Guide::Store::ID)
        id = WoodsMap::Guide::Store.generate_id
        cookies.signed[COOKIE] = { value: id, httponly: true, same_site: :strict, secure: request.ssl? }
      end
      WoodsMap::Guide::Store.new(woods_map_config.guide_chats_path, id)
    end
  end
end
