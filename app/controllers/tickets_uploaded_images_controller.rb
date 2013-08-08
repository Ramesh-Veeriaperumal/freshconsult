class TicketsUploadedImagesController < ApplicationController

  include UploadedImagesControllerMethods

  skip_before_filter :check_privilege

  private
    def cname
      "Tickets Image"
    end
end