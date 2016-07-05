class TicketTemplatesUploadedImagesController < ApplicationController

  include UploadedImagesControllerMethods

  skip_before_filter :check_privilege

  private
    def cname
      "Templates Image"
    end
end