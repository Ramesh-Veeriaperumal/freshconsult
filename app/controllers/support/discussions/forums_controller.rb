class Support::Discussions::ForumsController < SupportController
	before_filter { |c| c.requires_feature :forums }
 	before_filter { |c| c.check_portal_scope :open_forums }
  	before_filter :find_or_initialize_forum
  	before_filter do |c|
		c.send(:set_portal_page, :topic_list)
	end

	def show
		# (session[:forums] ||= {})[@forum.id] = Time.now.utc if logged_in?
	 #    (session[:forum_page] ||= Hash.new(1))[@forum.id] = params[:page].to_i if params[:page]

	 #    if @forum.ideas? and params[:order].blank?
	 #      conditions =  {:stamp_type => params[:stamp_type]} unless params[:stamp_type].blank?
	 #      @topics = @forum.topics.find(:all, :include => :votes, :conditions => conditions).sort_by { |u| [-u.sticky,-u.votes.size] }
	 #    else
	 #      params[:order] = "created_at" if params[:order].blank? 
	 #      params[:order] = params[:order] + " desc" unless params[:order].include?("desc")
	 #      params[:order] = "sticky desc, #{params[:order]}"
	 #      @topics = @forum.topics.find(:all,:order => params[:order])
	 #    end
	    
		
		# @topics = @forum.topics.paginate(
  #         							:page => params[:page], 
  #         							:per_page => 10)
		# @category = @forum.forum_category
		# @topics_filters = render_to_string :partial => "filters"
	end

private
	def scoper
	   current_account.portal_forums
	end	

	def find_or_initialize_forum 
		@forum = scoper.find_by_id(params[:id])
		redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) if !@forum.nil? and !@forum.visible?(current_user) 
    end	
end