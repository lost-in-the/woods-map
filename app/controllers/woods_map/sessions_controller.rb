# frozen_string_literal: true

module WoodsMap
  # Exchanges the bearer token for a signed, HttpOnly, SameSite=Strict cookie
  # so browser navigations can authenticate without a header. The form is the
  # fallback for `GET /woods?token=…`, which exchanges in one step.
  class SessionsController < ApplicationController
    skip_before_action :exchange_query_token!
    skip_before_action :authenticate!, only: %i[new create]
    layout 'woods_map/bare', only: %i[new create]

    def new
      head :not_found unless woods_map_config.token?
    end

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
  end
end
