# frozen_string_literal: true

module WoodsMap
  # The home page until M1 lands the unit pages: generation, counts and
  # provenance of the pinned index.
  class StatusController < ApplicationController
    def show
      @status = WoodsMap::Repository.open(&:status)
    end
  end
end
