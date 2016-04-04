class EmailNotificationUploadedImagesController < ApplicationController

	include UploadedImagesControllerMethods

	skip_before_filter :check_privilege

	private
		def cname
			"Email Notification Image"
		end
end