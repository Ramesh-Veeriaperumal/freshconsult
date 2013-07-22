class ForumsUploadedImagesController < ApplicationController

	include UploadedImagesControllerMethods

	skip_before_filter :check_privilege

	private
		def cname
			"Forums Image"
		end
end