# frozen_string_literal: true

module WoodsMap
  # The home page until M1 lands the unit pages: generation, HEAD, counts and
  # host facts of the pinned index, as the States board draws the status page.
  class StatusController < ApplicationController
    def show
      with_repository do |repository|
        @status = repository.status
        @freshness = repository.freshness
        @retention = repository.retention
        @files_sheet = true
      end
    end
  end
end
