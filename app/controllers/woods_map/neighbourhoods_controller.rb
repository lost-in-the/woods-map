# frozen_string_literal: true

module WoodsMap
  # JSON-only projection behind the same host and token gate as the HTML graph.
  class NeighbourhoodsController < ApplicationController
    prepend_before_action :json_response
    rescue_from NeighbourhoodQuery::Invalid, with: :invalid_query

    # @return [void] authenticated JSON from one published generation
    def show
      query = NeighbourhoodQuery.new(params)
      with_repository do |repository|
        values = query.to_h
        unless repository.graph_node(values['centre'], type: values['type'])
          next render json: { error: 'unit_not_found' }, status: :not_found
        end

        render json: NeighbourhoodResponse.new(repository, query).to_h
      end
    end

    private

    def json_response
      request.format = :json
      response.headers['Cache-Control'] = 'no-store'
    end

    def invalid_query(error)
      render json: { error: 'invalid_query', message: error.message }, status: :bad_request
    end

    def render_unavailable(_error)
      render json: { error: 'index_unavailable' }, status: :service_unavailable
    end

    def refuse(_reason)
      render json: { error: 'forbidden' }, status: :forbidden
    end
  end
end
