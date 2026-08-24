# frozen_string_literal: true

module Api::V1
  # GET /api/v1/countries — страны, отношения, эмбарго, цены (FR-25).
  class CountriesController < BaseController
    def index
      render json: { countries: CaravanService.countries_view }
    end
  end
end
