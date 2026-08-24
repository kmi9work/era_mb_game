# frozen_string_literal: true

class Api::V1::BaseController < ApplicationController
  include PlayerAuthenticable
end
