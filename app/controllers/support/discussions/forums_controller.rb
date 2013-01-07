class Support::Discussions::ForumsController < SupportController
	before_filter { |c| c.requires_feature :forums }
 	before_filter { |c| c.check_portal_scope :open_forums }
 	before_filter :load_forum, :only => :show

	def show
	    set_portal_page :topic_list
	end

private
	def load_forum 
		@forum = current_portal.portal_forums.visible(current_user).find_by_id(params[:id])
		redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) if !@forum.nil? and !@forum.visible?(current_user) 
    end
end