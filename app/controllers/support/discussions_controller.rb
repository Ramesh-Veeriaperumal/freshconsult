class Support::DiscussionsController < SupportController
	# before_filter :scoper
	before_filter { |c| c.requires_feature :forums }
	before_filter { |c| c.check_portal_scope :open_forums }
	before_filter :allow_monitor?, :only => [:user_monitored]

	def index
		set_portal_page :discussions_home
	end

	def show
		# @category = current_portal.forum_categories.find_by_id(params[:id])
		set_portal_page :discussions_home
	end	

    def user_monitored
	    # @monitorships  = Monitorship.active_monitors.find(:all,:conditions=>["user_id = ?",params[:user_id]])
	    @monitorships = current_account.portal_topics.find(:all,:conditions=>["user_id = ?",params[:user_id]])
	    respond_to do |format|
	      format.xml { render :xml => @monitorships.to_xml(:except=>:account_id) }
	      format.json { render :json => @monitorships.as_json(:except=>:account_id) }
	    end
  	end

end