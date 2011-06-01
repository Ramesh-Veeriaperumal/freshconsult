class TopicsController < ApplicationController
  before_filter :find_forum_and_topic, :except => :index 
  before_filter :except => [:index, :show] do |c| 
    c.requires_permission :post_in_forums
  end
  
  before_filter :only => [:update_stamp,:remove_stamp,:destroy] do |c| 
    c.requires_permission :manage_forums
  end
  
  before_filter { |c| c.requires_feature :forums }
  before_filter { |c| c.check_portal_scope :open_forums }
  before_filter :check_user_permission,:only => [:edit,:update] 
  
  before_filter :set_selected_tab
  
  #uses_tiny_mce :options => Helpdesk::MEDIUM_EDITOR 

	# @WBH@ TODO: This uses the caches_formatted_page method.  In the main Beast project, this is implemented via a Config/Initializer file.  Not
	# sure what analogous place to put it in this plugin.  It don't work in the init.rb  
  #caches_formatted_page :rss, :show
  cache_sweeper :posts_sweeper, :only => [:create, :update, :destroy]

  def check_user_permission
    if (current_user.id != @topic.user_id and  !current_user.has_manage_forums?)
          flash[:notice] =  t(:'flash.general.access_denied')
          redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
    end
  end
  
  
  def index
    respond_to do |format|
      format.html { redirect_to forum_path(params[:forum_id]) }
      format.xml do
        @topics = Topic.paginate_by_forum_id(params[:forum_id], :order => 'sticky desc, replied_at desc', :page => params[:page])
        render :xml => @topics.to_xml
      end
    end
  end

  def new
    @topic = Topic.new
  end
  
  def show
    
    respond_to do |format|
      format.html do
        # see notes in application.rb on how this works
        update_last_seen_at
        # keep track of when we last viewed this topic for activity indicators
        (session[:topics] ||= {})[@topic.id] = Time.now.utc if logged_in?
        # authors of topics don't get counted towards total hits
        @topic.hit! unless logged_in? and @topic.user == current_user
        @posts = @topic.posts.paginate :page => params[:page]
        @post   = Post.new
      end
      format.xml do
        render :xml => @topic.to_xml(:include => :posts)
      end
      format.json do
        render :json => @topic.to_json(:include => :posts)
      end
      format.rss do
        @posts = @topic.posts.find(:all, :order => 'created_at desc', :limit => 25)
        render :action => 'show', :layout => false
      end
    end
  end
  
  def create
    topic_saved, post_saved = false, false
		# this is icky - move the topic/first post workings into the topic model?
    Topic.transaction do
      @topic  = @forum.topics.build(params[:topic])
      assign_protected
      @post       = @topic.posts.build(params[:topic])
      @post.topic = @topic
      @post.user  = current_user
      @post.account_id = current_account.id
      # only save topic if post is valid so in the view topic will be a new record if there was an error
      @topic.body = @post.body # incase save fails and we go back to the form
      topic_saved = @topic.save if @post.valid?
      post_saved = @post.save 
    end
		
		if topic_saved && post_saved
      @topic.monitorships.create(:user_id => current_user.id,:active => true) if params[:monitor] 
      create_attachments  
			respond_to do |format| 
				format.html { redirect_to category_forum_topic_path(@forum_category,@forum, @topic) }
				format.xml  { render  :xml => @topic }
			end
	else
   respond_to do |format|  
			format.html { render :action => "new" }
      format.xml  { render  :xml => @topic.errors }
   end
		end
  end
  
  def update
    topic_saved, post_saved = false, false
    Topic.transaction do
      @topic.attributes = params[:topic]
      assign_protected
      @post = @topic.posts.first
      @post.attributes = params[:topic]
      @topic.body = @post.body 
      topic_saved = @topic.save
      post_saved = @post.save
    end
    if topic_saved && post_saved
      create_attachments
      respond_to do |format|
        format.html { redirect_to category_forum_topic_path(@topic.forum.forum_category_id,@topic.forum_id, @topic) }
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
    flash[:notice] = "Topic '{title}' was deleted."[:topic_deleted_message, @topic.title]
    respond_to do |format|
      format.html { redirect_to  category_forum_path(@forum_category,@forum) }
      format.xml  { head 200 }
    end
  end
  
   def update_stamp
    if  @topic.update_attributes(:stamp_type => params[:stamp_type])
      respond_to do |format|
        format.html { redirect_to category_forum_topic_path(@forum_category,@forum, @topic) }
        format.xml  { head 200 }
      end
     end
  end
    
  def remove_stamp
    if @topic.update_attributes(:stamp_type => nil) 
     respond_to do |format|
      format.html { redirect_to category_forum_topic_path(@forum_category,@forum, @topic) }
      format.xml  { head 200 }
    end
   end
 end
 

 def vote   
  unless @topic.voted_by_user?(current_user)  
    @vote = Vote.new(:vote => params[:vote] == "for")  
    @vote.user_id = current_user.id  
    @topic.votes << @vote
    render :partial => "forum_shared/topic_vote", :object => @topic
  end  
end 

def destroy_vote   
   @votes = Vote.find(:all, :conditions => ["user_id = ? and voteable_id = ?", current_user.id, params[:id]] )
   @votes.first.destroy
   render :partial => "forum_shared/topic_vote", :object => @topic
 
end  

def update_lock
  @topic.locked = !@topic.locked
  @topic.save!
   respond_to do |format|
      format.html { redirect_to category_forum_topic_path(@forum_category,@forum, @topic) }
      format.xml  { head 200 }
   end
end

 def create_attachments
   return unless @topic.posts.first.respond_to?(:attachments) 
    unless params[:post].nil?
    (params[:post][:attachments] || []).each do |a|
      @topic.posts.first.attachments.create(:content => a[:file], :description => a[:description], :account_id => @topic.posts.first.account_id)
    end
   end
  end
 
  
  protected
    def assign_protected
      @topic.user     = current_user if @topic.new_record?
      @topic.account_id = current_account.id
      # admins and moderators can sticky and lock topics
      return unless admin? or current_user.moderator_of?(@topic.forum)
      @topic.sticky, @topic.locked = params[:topic][:sticky], params[:topic][:locked] 
      # only admins can move
      return unless admin?
      @topic.forum_id = params[:topic][:forum_id] if params[:topic][:forum_id]
    end
    
    def find_forum_and_topic
       @forum_category = scoper.find(params[:category_id])
       @forum = @forum_category.forums.find(params[:forum_id])
       raise(ActiveRecord::RecordNotFound) unless (@forum.account_id == current_account.id)
       redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) unless @forum.visible?(current_user)
       @topic = @forum.topics.find(params[:id]) if params[:id]
    end
    def scoper
      current_account.forum_categories
    end
    
    def set_selected_tab
      @selected_tab = 'Forums'
    end
  
    
#    def authorized?
#      %w(new create).include?(action_name) || @topic.editable_by?(current_user)
#    end
end
