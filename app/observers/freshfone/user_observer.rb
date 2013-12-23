class Freshfone::UserObserver < ActiveRecord::Observer
	observe Freshfone::User

	include Freshfone::NodeEvents

	def after_save(freshfone_user)
		publish_presence(freshfone_user) if freshfone_user.presence_changed?
	end

	def after_destroy(freshfone_user)
		publish_presence(freshfone_user, true)
	end
	
	private
		def publish_presence(freshfone_user, deleted=false)
			publish_freshfone_presence(freshfone_user, freshfone_user.user, deleted)
		end
end