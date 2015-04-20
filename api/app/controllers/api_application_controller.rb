class ApiApplicationController < ApplicationController
  respond_to :json
  after_filter :latest_version

  def latest_version
    response.headers["Latest-Version"] = "2"
  end
end