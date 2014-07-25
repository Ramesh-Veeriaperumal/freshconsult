class Support::Discussions::ForumsController < SupportController

	include SupportDiscussionsControllerMethods

	before_filter { |c| c.requires_feature :forums }
	before_filter :check_forums_state
	before_filter { |c| c.check_portal_scope :open_forums }
	before_filter :load_forum, :only => [:show, :toggle_monitor]

	def show
		respond_to do |format|
			format.html { 
        load_page_meta
        set_portal_page :topic_list 
      }
		end
	end

private
	def load_forum 
		@forum = current_portal.portal_forums.visible(current_user).find_by_id(params[:id])
		redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) if !@forum.nil? and !@forum.visible?(current_user) 
		render_404 if @forum.nil?
	end
  
  def load_page_meta
    @page_meta ||= {
      :title => @forum.name,
      :description => @forum.description,
      :canonical => support_discussions_forum_url(@forum)
    }
  end
end