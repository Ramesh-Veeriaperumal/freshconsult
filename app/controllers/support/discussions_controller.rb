class Support::DiscussionsController < SupportController
	# before_filter :scoper
	before_filter :load_category, :only => :show
  before_filter :check_forums_access
	before_filter { |c| c.requires_feature :forums }
	before_filter :check_forums_state
	before_filter { |c| c.check_portal_scope :open_forums }
	before_filter :allow_monitor?, :only => [:user_monitored]

	def index
		respond_to do |format|
			format.html {
				load_agent_actions(categories_discussions_path, :view_forums)
				set_portal_page :discussions_home 
			}
		end
	end

	def show  
		respond_to do |format|
			format.html { 
				load_agent_actions(discussion_path(@category), :view_forums)
				load_page_meta
				set_portal_page :discussions_category 
			}
		end
	end	

    def user_monitored
    	stmt = "inner join #{Monitorship.table_name} on #{Topic.table_name}.id = #{Monitorship.table_name}.monitorable_id and #{Monitorship.table_name}.monitorable_type = 'Topic' and #{Topic.table_name}.account_id = #{Monitorship.table_name}.account_id"
    	contd = ["#{Monitorship.table_name}.active= ? and #{Monitorship.table_name}.user_id = ?", true, params[:user_id]]
        # setting it to 10 as default count or if count mentioned >30.Never allow >30
    	per_page = params[:count_per_page].blank? || params[:count_per_page].to_i > 30 ? 10 : params[:count_per_page]
	    @topics = current_account.topics.joins(stmt).where(contd).paginate(page: params[:page], per_page: per_page)
	    respond_to do |format|
	      format.xml { render :xml => @topics.to_xml(:except=>:account_id) }
	      format.json { render :json => @topics.as_json(:except=>[:account_id]) }
	    end
  	end

  	private
		def load_category
			@category = current_portal.forum_categories.find_by_id(params[:id])
				(raise ActiveRecord::RecordNotFound and return) if @category.blank? || params[:id] !~ /^[0-9]*$/
		end
    
    def load_page_meta
      @page_meta ||= {
        :title => @category.name,
        :description => @category.description,
        :canonical => page_canonical
      }
    end

    def page_canonical
      if current_portal.forum_categories.size == 1
        support_discussions_url(:host => current_portal.host)
      else
        support_discussion_url(@category, :host => current_portal.host)
      end
    end
end 
