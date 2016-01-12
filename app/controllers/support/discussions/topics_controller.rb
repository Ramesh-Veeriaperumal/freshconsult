class Support::Discussions::TopicsController < SupportController

  include Community::Moderation
  include SupportDiscussionsControllerMethods
  include SpamAttachmentMethods
  include CloudFilesHelper
  include Community::Voting

  before_filter :load_topic, :only => [:show, :edit, :update, :like, :unlike, :toggle_monitor,
                                      :users_voted, :destroy, :toggle_solution, :hit]
  before_filter :require_user, :except => [:index, :show, :hit]

  before_filter :check_forums_access, :only => [:new, :show]
  before_filter { |c| c.requires_feature :forums }
  before_filter :check_forums_state
  before_filter { |c| c.check_portal_scope :open_forums }
  before_filter :check_user_permission, :only => :destroy
  before_filter :set_sort_by, :only => :show
  before_filter :fetch_vote, :toggle_vote, :only => [:like, :unlike]

  before_filter :allow_monitor?, :only => [:monitor,:check_monitor]
  # @WBH@ TODO: This uses the caches_formatted_page method.  In the main Beast project, this is implemented via a Config/Initializer file.  Not
  # sure what analogous place to put it in this plugin.  It don't work in the init.rb
  #caches_formatted_page :rss, :show
  # cache_sweeper :posts_sweeper, :only => [:create, :update, :destroy]

  def check_user_permission
    if (current_user.id != @topic.user_id)
          flash[:notice] =  t(:'flash.general.access_denied')
          redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
    end
  end

  def index
    respond_to do |format|
      format.html { redirect_to forum_path(params[:forum_id]) }
      format.xml do
        @topics = Topic.paginate_by_forum_id(params[:forum_id], :order => 'sticky desc, replied_at desc', :page => params[:page])
        return render :xml => @topics.to_xml
      end
    end
  end

  def show
    respond_to do |format|
      format.html do
        load_agent_actions(discussions_topic_path(@topic), :view_forums)
        @post = Post.new
        load_page_meta
        set_portal_page :topic_view
      end
      format.xml do
        return render :xml => @topic.to_xml(:include => :posts)
      end
      format.json do
        return render :json => @topic.to_json(:include => :posts)
      end
      format.rss do
        @posts = @topic.posts.find(:all, :order => 'created_at desc', :limit => 25)
        return render(:action => 'show', :layout => false)
      end
    end
  end

  def hit
    # keep track of when we last viewed this topic for activity indicators
    (session[:topics] ||= {})[@topic.id] = Time.now.utc if logged_in?
    # authors of topics don't get counted towards total hits
    @topic.hit! unless logged_in? and (@topic.user == current_user or current_user.agent?)

    render_tracker
  end

  def new
    respond_to do |format|
      format.html { set_portal_page :new_topic }
    end
  end


  def edit
    redirect_to support_discussions_topic_path(@topic.id)
  end

  def create
		@forum = forum_scoper.find(params[:topic][:forum_id])
    (redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) and return) unless @forum.visible?(current_user) 
		if @forum.announcement?
			flash[:notice] = t(".flash.portal.discussions.topics.not_allowed")
			creation_response(false) 
			return
		end
		@topic  = @forum.topics.build(topic_param)
		@topic.body_html = params[:topic][:body_html] # incase save fails and we go back to the form
		creation_response(cleared_captcha && (current_user.customer? ? sqs_create : create_in_db))
	end

	def sqs_create
		sqs_post = SQSPost.new(sqs_post_param)

		sqs_post.save
	end

	def create_in_db
		# this is icky - move the topic/first post workings into the topic model?
		assign_protected 
		@post = @topic.posts.build(post_param.merge(post_request_params))

		@post.topic = @topic
		@post.user  = current_user
		@post.account_id = current_account.id
		@post.portal = current_portal.id
		build_attachments

		@topic.save
	end

  def update
    respond_to do |format|
      format.html { redirect_to support_discussions_topic_path(@topic) }
      format.xml  { head 200 }
    end
  end

  def destroy
    @topic.destroy
    flash[:notice] = I18n.t('flash.topic.deleted', :title => h(@topic.title)).html_safe
    respond_to do |format|
      format.html { redirect_to support_discussions_path }
    end
  end

  def toggle_solution
    @topic.toggle_solved_stamp
    respond_to do |format|
      format.html { redirect_to support_discussions_topic_path(@topic) }
      format.xml  { head 200 }
    end
  end

  #method to fetch the monitored status of the topic given the user_id
  def check_monitor
    @monitorship = Monitorship.find_by_user_id_and_monitorable_id_and_monitorable_type(params[:user_id], params[:id], "Topic")
    @monitorship = [] if @monitorship.nil? || !@monitorship.active
    respond_to do |format|
      format.xml { render :xml => @monitorship.to_xml(:except=>:account_id) }
      format.json { render :json => @monitorship.as_json(:except=>:account_id) }
    end
  end

  #method to set the monitored status of the topic given the user_id and monitor status
  def monitor
    @monitorship = Monitorship.find_by_user_id_and_monitorable_id_and_monitorable_type(params[:user_id], params[:id], "Topic")
    @monitorship.update_attribute(:active,params[:status]) unless params[:status].blank?
    respond_to do |format|
      format.xml { render :xml => @monitorship.to_xml(:except=>:account_id) }
      format.json { render :json => @monitorship.as_json(:except=>:account_id) }
    end
  end

  def like
    render :partial => "topic_vote", :object => @topic
  end

  def unlike
    render :partial => "topic_vote", :object => @topic
  end

  def my_topics
    set_portal_page :my_topics
  end

  def update_lock
    @topic.locked = !@topic.locked
    @topic.save!
     respond_to do |format|
        format.html { redirect_to discussions_topic_path(@topic) }
        format.xml  { head 200 }
     end
  end

  def users_voted
    render :partial => "users_voted", :object => @topic
  end

  def build_attachments
    post_attachments = params[:post].nil? ? [] : params[:post][:attachments]
    attachment_builder(@post, post_attachments, params[:cloud_file_attachments] )
  end

  def reply
    redirect_to "#{support_discussions_topic_path(params[:id])}/page/last#reply-to-post"
  end

  protected
    def assign_protected
      @topic.user     = current_user if @topic.new_record?
      @topic.account_id = current_account.id
      # admins and moderators can sticky and lock topics
      return unless privilege?(:manage_users) or current_user.moderator_of?(@topic.forum)
      # only admins can move
      return unless privilege?(:manage_users)
      @topic.forum_id = params[:topic][:forum_id] if params[:topic][:forum_id]
    end

    def load_topic
      @topic = scoper.find_by_id(params[:id])
      
      if @topic.nil?
        resource_not_found :topic
      else
        @forum = @topic.forum
        @forum_category = @forum.forum_category
      
        wrong_portal and return unless current_portal.has_forum_category?(@forum_category)
        raise(ActiveRecord::RecordNotFound) unless (@forum.account_id == current_account.id)

        unless @forum.visible?(current_user)
          store_location
          redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) 
        end
      end
    end
    
    def load_page_meta
      @page_meta ||= {
        :title => @topic.title,
        :description => @topic.posts.published.first['body'],
        :canonical => support_discussions_topic_url(@topic, :host => current_portal.host)
      }
    end

    def scoper
      current_account.portal_topics.published
    end

    def forum_scoper
      current_portal.portal_forums
    end

    def creation_response(success)
      if success
        respond_to do |format|
          format.html {
            flash[:notice] = flash_msg_on_topic_create
            redirect_to support_discussions_path
          }
          # format.xml  { render :xml => @topic } #should be discussed!
        end
      else
        respond_to do |format|
          format.html {
            set_portal_page :new_topic
            render :new
          }
          format.xml  { render :xml => @topic.errors }
        end
      end
    end

    def topic_param
      param = params[:topic].symbolize_keys
      param.delete_if{|k, v| [:body_html].include? k }
      return param
    end

    def post_param
      param =  params[:topic].symbolize_keys
      param.delete_if{|k, v| [:title,:sticky,:locked].include? k }
      return param
    end

    def post_request_params
      {
        :request_params => {
          :user_ip => request.remote_ip,
          :referrer => request.referrer,
          :user_agent => request.env['HTTP_USER_AGENT']
        }
      }
    end

    def sqs_post_param
      {
        :topic => { :title => topic_param[:title], :forum_id => @forum.id },
        :attachments => processed_attachments,
        :cloud_file_attachments => params["cloud_file_attachments"] || [],
        :portal => current_portal.id
      }.merge(post_param.clone.delete_if { |k,v| k == :forum_id }).merge(post_request_params)
    end

    def cleared_captcha
      current_account.features_included?(:forum_captcha_disable) || verify_recaptcha(:model => @topic, :message => t("captcha_verify_message"))
    end

    def set_sort_by
      @topic.sort_by = params[:sort] || 'date'
    end

    def vote_parent
      @topic
    end
end
