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
    	options={}
    	options[:joins]= "inner join #{Monitorship.table_name} on #{Topic.table_name}.id = #{Monitorship.table_name}.topic_id and #{Topic.table_name}.account_id = #{Monitorship.table_name}.account_id"
    	options[:conditions] = ["#{Monitorship.table_name}.active=? and #{Monitorship.table_name}.user_id = ?",true,params[:user_id]]
    	options[:page] = params[:page]
    	# setting it to 10 as default count or if count mentioned >30.Never allow >30
    	options[:per_page] = (params[:count_per_page].blank? || params[:count_per_page].to_i>30) ? 10 : params[:count_per_page]
	    @topics = current_account.topics.paginate(options)
	    respond_to do |format|
	      format.xml { render :xml => @monitorships.to_xml(:except=>:account_id) }
	      format.json { render :json => @monitorships.as_json(:except=>:account_id) }
	    end
  	end

end