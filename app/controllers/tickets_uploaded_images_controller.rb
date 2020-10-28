class TicketsUploadedImagesController < ApplicationController

  include UploadedImagesControllerMethods

  skip_before_filter :check_privilege
  before_filter :check_anonymous_user

  private
    def cname
      "Tickets Image"
    end

    def check_anonymous_user
      render json: { error: ErrorConstants::ERROR_MESSAGES[:invalid_credentials] } unless logged_in?
    end
end
