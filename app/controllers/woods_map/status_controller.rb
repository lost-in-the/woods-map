# frozen_string_literal: true

module WoodsMap
  # The home page until M1 lands the unit pages: generation, HEAD, counts and
  # host facts of the pinned index, as the States board draws the status page.
  class StatusController < ApplicationController
    def show
      @status = with_repository(&:status)
    end
  end
end
