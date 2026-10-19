# frozen_string_literal: true

module WoodsMap
  # The engine's copy of the component boards (C1 to C5), rendered from the
  # same partials every page uses, so the canvas and the engine cannot drift.
  # Works without an index: the bar then shows "no index".
  class GuidelinesController < ApplicationController
    def show
      @generation = WoodsMap::Repository.open(&:generation_facts)
    rescue WoodsMap::Repository::Unavailable
      @generation = nil
    end
  end
end
