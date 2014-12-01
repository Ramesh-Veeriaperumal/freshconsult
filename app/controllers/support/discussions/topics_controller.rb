class Support::Discussions::TopicsController < SupportController

  include Community::Moderation
  include SupportDiscussionsControllerMethods
  include CloudFilesHelper
  before_filter :load_topic, :only => [:show, :edit, :update, :like, :unlike, :toggle_monitor,
                                      :users_voted, :destroy, :toggle_solution, :hit]
  before_filter :require_user, :except => [:index, :show, :hit]

  before_filter :load_agent_actions, :only => :show
  before_filter { |c| c.requires_feature :forums }
  before_filter :check_forums_state
  before_filter { |c| c.check_portal_scope :open_forums }
  before_filter :check_user_permission, :only => [:edit, :update, :destroy]

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
    if @topic.merged_topic_id?
      flash[:notice] = I18n.t('discussions.topic_merge.merge_error_for_locked', 
                      :title => h(@topic.merged_into.title), 
                      :topic_link => discussions_topic_path(@topic.merged_topic_id)).html_safe
      redirect_to discussions_topic_path(params[:id])
    else
      respond_to do |format|
        format.html {
          set_portal_page :new_topic
          render :new
        }
      end
    end
  end

  def create
    topic_saved, post_saved = false, false
    @forum = forum_scoper.find(params[:topic][:forum_id])
    # this is icky - move the topic/first post workings into the topic model?
    Topic.transaction do
      @topic  = @forum.topics.build(topic_param)
      assign_protected
      @post       = @topic.posts.build(post_param.merge(post_request_params))
      @post.topic = @topic
      @post.user  = current_user
      @post.account_id = current_account.id
      @post.portal = current_portal.id
      # only save topic if post is valid so in the view topic will be a new record if there was an error
      @topic.body_html = @post.body_html # incase save fails and we go back to the form
      build_attachments
      if verify_recaptcha(:model => @topic, :message => t("captcha_verify_message"))
        topic_saved = @post.valid? and @topic.save
        post_saved = @post.save
      end
    end

    if topic_saved && post_saved
      respond_to do |format|
        format.html {
          flash[:notice] = flash_msg_on_topic_create
          redirect_to support_discussions_path
        }
        format.xml  { render :xml => @topic }
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

  def update
    topic_saved, post_saved = false, false
    Topic.transaction do
      @topic.attributes = topic_param
      assign_protected
      @post = @topic.posts.first
      @post.attributes = post_param
      @topic.body_html = @post.body_html
      build_attachments
      topic_saved = @topic.save
      post_saved = @post.save
    end
    if topic_saved && post_saved
      respond_to do |format|
        format.html { redirect_to support_discussions_topic_path(@topic) }
        format.xml  { head 200 }
      end
    else
     respond_to do |format|
       format.html { render :action => "edit" }
     end

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
    unless @topic.voted_by_user?(current_user)
      @vote = Vote.new(:vote => params[:vote] == "for")
      @vote.user_id = current_user.id
      @topic.votes << @vote
    end
    load_topic
    render :partial => "topic_vote", :object => @topic
  end

  def unlike
     @votes = Vote.find(:all, :conditions => ["user_id = ? and voteable_id = ?", current_user.id, params[:id]] )
     @votes.first.destroy
     load_topic
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
      @topic = scoper.find(params[:id])
      @forum = @topic.forum
      @forum_category = @forum.forum_category

      wrong_portal unless(main_portal? || (@forum_category.id.to_i == current_portal.forum_category_id)) #Duplicate
      raise(ActiveRecord::RecordNotFound) unless (@forum.account_id == current_account.id)
      
      unless @forum.visible?(current_user)
        store_location
        redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) 
      end
    end
    
    def load_page_meta
      @page_meta ||= {
        :title => @topic.title,
        :description => @topic.posts.published.first['body'],
        :canonical => support_discussions_topic_url(@topic)
      }
    end

    def scoper
      current_account.portal_topics.published
    end

    def forum_scoper
      current_portal.portal_forums
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

    def load_agent_actions
      @agent_actions = []
      @agent_actions <<   { :url => discussions_topic_path(@topic),
                            :label => t('portal.preview.view_on_helpdesk'),
                            :icon => "preview" } if privilege?(:view_forums)
      @agent_actions
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

end
