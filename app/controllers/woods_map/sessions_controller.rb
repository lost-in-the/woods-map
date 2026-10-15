# frozen_string_literal: true

module WoodsMap
  # Exchanges the bearer token for a signed, HttpOnly, SameSite=Strict cookie
  # so browser navigations can authenticate without a header.
  class SessionsController < ApplicationController
    skip_before_action :authenticate!, only: %i[new create]

    def new
      head :not_found unless woods_map_config.token?
    end

    REJECTED = 'That token was not accepted.'

    def create
      if token_matches?(params[:token].to_s)
        store_session_cookie
        redirect_to woods_map.root_path
      else
        flash.now[:alert] = REJECTED
        render :new, status: :unauthorized
      end
    end

    def destroy
      cookies.delete(woods_map_config.cookie_name)
      redirect_to woods_map.new_session_path
    end

    private

    def token_matches?(presented)
      woods_map_config.token? && Rack::Utils.secure_compare(woods_map_config.token, presented)
    end

    def store_session_cookie
      cookies.signed[woods_map_config.cookie_name] = {
        value: token_digest, httponly: true, same_site: :strict, secure: request.ssl?
      }
    end
  end
end
