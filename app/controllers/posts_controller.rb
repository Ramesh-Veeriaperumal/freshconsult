class PostsController < ApplicationController
  before_filter :find_post,      :except => [:index, :create, :monitored, :search]
  #before_filter :login_required, :except => [:index, :monitored, :search, :show]
  before_filter :except => [:index, :monitored, :search, :show] do |c| 
    c.requires_permission :post_in_forums
  end
  
  before_filter { |c| c.requires_feature :forums }
  before_filter { |c| c.check_portal_scope :open_forums }
  before_filter :check_user_permission,:only => [:edit,:destroy,:update] 
  
  @@query_options = { :select => "#{Post.table_name}.*, #{Topic.table_name}.title as topic_title, #{Forum.table_name}.name as forum_name", :joins => "inner join #{Topic.table_name} on #{Post.table_name}.topic_id = #{Topic.table_name}.id inner join #{Forum.table_name} on #{Topic.table_name}.forum_id = #{Forum.table_name}.id" }

	# @WBH@ TODO: This uses the caches_formatted_page method.  In the main Beast project, this is implemented via a Config/Initializer file.  Not
	# sure what analogous place to put it in this plugin.  It don't work in the init.rb
  #caches_formatted_page :rss, :index, :monitored
  cache_sweeper :posts_sweeper, :only => [:create, :update, :destroy]
  
  def check_user_permission
    if (current_user.id != @post.user_id and  !current_user.has_manage_forums?)
          flash[:notice] =  "You don't have sufficient privileges to access this page"
          redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
    end
  end

  def index
    conditions = []
    [:user_id, :forum_id, :topic_id].each { |attr| conditions << Post.send(:sanitize_sql, ["#{Post.table_name}.#{attr} = ?", params[attr]]) if params[attr] }
    conditions << Post.send(:sanitize_sql, ["#{Post.table_name}.account_id = ?", current_account.id]) #by Shan temp
    conditions = conditions.empty? ? nil : conditions.collect { |c| "(#{c})" }.join(' AND ')
    #@posts = Post.paginate @@query_options.merge(:conditions => conditions, :page => params[:page], :count => {:select => "#{Post.table_name}.id"}, :order => post_order, :limit =>10 )
    @posts = Post.find(:all,:conditions => conditions, :order => post_order, :limit =>10 )
    @users = current_account.users.find(:all, :select => 'distinct *', :conditions => ['id in (?)', @posts.collect(&:user_id).uniq]).index_by(&:id)
    render_posts_or_xml
  end

#  def search		#by Shan temp
#    conditions = params[:q].blank? ? nil : Post.send(:sanitize_sql, ["LOWER(#{Post.table_name}.body) LIKE ?", "%#{params[:q]}%"])
#    @posts = Post.paginate @@query_options.merge(:conditions => conditions, :page => params[:page], :count => {:select => "#{Post.table_name}.id"}, :order => post_order)
#    @users = User.find(:all, :select => 'distinct *', :conditions => ['id in (?)', @posts.collect(&:user_id).uniq]).index_by(&:id)
#    render_posts_or_xml :index
#  end

  def monitored
    @user = current_account.users.find params[:user_id]
    options = @@query_options.merge(:conditions => ["#{Monitorship.table_name}.user_id = ? and #{Post.table_name}.user_id != ? and #{Monitorship.table_name}.active = ?", params[:user_id], @user.id, true])
    options[:order]  = post_order
    options[:joins] += " inner join #{Monitorship.table_name} on #{Monitorship.table_name}.topic_id = #{Topic.table_name}.id"
    options[:page]   = params[:page]
    options[:count]  = {:select => "#{Post.table_name}.id"}
    @posts = Post.paginate options
    render_posts_or_xml
  end

  def show
    respond_to do |format|
      format.html { redirect_to category_forum_topic_path(:category_id => params[:category_id],:forum_id => params[:forum_id], :id => params[:topic_id]) }
      format.xml  { render :xml => @post.to_xml }
    end
  end

  def create
    @topic = Topic.find_by_id_and_forum_id_and_account_id(params[:topic_id],params[:forum_id],current_account.id)
    #raise(ActiveRecord::RecordNotFound) unless (@topic.account_id == current_account.id) #by Shan
    
    if @topic.locked?
      respond_to do |format|
        format.html do
          flash[:notice] = 'This topic is locked.'[:locked_topic]
          redirect_to(category_forum_topic_path(:category_id => params[:category_id],:forum_id => params[:forum_id], :id => params[:topic_id]))
        end
        format.xml do
          render :text => 'This topic is locked.'[:locked_topic], :status => 400
        end
      end
      return
    end
    @forum = @topic.forum
    @post  = @topic.posts.build(params[:post])
    @post.user = current_user
    @post.account_id = current_account.id
    @post.save!
    create_attachments
    respond_to do |format|
      format.html do
        redirect_to category_forum_topic_path(:category_id => params[:category_id],:forum_id => params[:forum_id], :id => params[:topic_id], :anchor => @post.dom_id, :page => params[:page] || '1')
      end
      format.xml { render :xml => @post }
    end
  rescue ActiveRecord::RecordInvalid
    flash[:bad_reply] = 'Please post a valid message...'[:post_something_message]
    respond_to do |format|
      format.html do
        redirect_to category_forum_topic_path(:category_id => params[:category_id],:forum_id => params[:forum_id], :id => params[:topic_id], :anchor => 'reply-form', :page => params[:page] || '1')
      end
      format.xml { render :xml => @post.errors.to_xml, :status => 400 }
    end
  end
  
   def create_attachments
   return unless @post.respond_to?(:attachments)
    (params[:post][:attachments] || []).each do |a|
      @post.attachments.create(:content => a[:file], :description => a[:description], :account_id => @post.account_id)
    end
  end
  
  def edit
    respond_to do |format| 
      format.html
      format.js
    end
  end
  
  def update
    @post.attributes = params[:post]
    @post.save!
  rescue ActiveRecord::RecordInvalid
    flash[:bad_reply] = 'An error occurred'[:error_occured_message]
  ensure
    respond_to do |format|
      format.html do
        redirect_to category_forum_topic_path(@post.topic.forum.forum_category_id,:forum_id => params[:forum_id], :id => params[:topic_id])
      end
      format.js
      format.xml { head 200 }
    end
  end

  def destroy
    @post.destroy
    flash[:notice] = "Post of '{title}' was deleted."[:post_deleted_message, @post.topic.title]
    respond_to do |format|
      format.html do
        redirect_to(@post.topic.frozen? ? 
          category_forum_path(@post.topic.forum.forum_category_id,:forum_id => params[:forum_id]) :
          category_forum_topic_path(@post.topic.forum.forum_category_id,:forum_id => params[:forum_id], :id => params[:topic_id]))
      end
      format.xml { head 200 }
    end
  end
  
  def toggle_answer
    @post.answer = !@post.answer
    @post.save
    respond_to do |format| 
        format.html { redirect_to category_forum_topic_path(params[:category_id],params[:forum_id], params[:topic_id]) }
        format.xml  { head :created, :location => topic_url(:forum_id => @forum, :id => @topic, :format => :xml) }
      end
  end

  protected
#    def authorized? #Commented by Shan
#      action_name == 'create' || @post.editable_by?(current_user)
#    end
    
    def post_order
      "#{Post.table_name}.created_at#{params[:forum_id] && params[:topic_id] ? nil : " desc"}"
    end
    
    def find_post			
			@post = Post.find_by_id_and_topic_id_and_forum_id(params[:id], params[:topic_id], params[:forum_id]) || raise(ActiveRecord::RecordNotFound)
      (raise(ActiveRecord::RecordNotFound) unless (@post.account_id == current_account.id)) || @post
    end
    
    def render_posts_or_xml(template_name = action_name)
      respond_to do |format|
        format.html { render :action => template_name }
        format.rss  { render :action => template_name, :layout => false }
        format.xml  { render :xml => @posts.to_xml }
      end
    end
end
