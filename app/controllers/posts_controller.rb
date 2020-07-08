class PostsController < ApplicationController
  
  include CloudFilesHelper
  rescue_from ActiveRecord::RecordNotFound, :with => :RecordNotFoundHandler

  before_filter :find_forum_topic, :only => [:create, :best_answer]
  before_filter :find_post,      :except =>  [:monitored, :create]
  
  before_filter { |c| c.requires_feature :forums }
  before_filter { |c| c.check_portal_scope :open_forums }
  
  @@query_options = { :select => "#{Post.table_name}.*, #{Topic.table_name}.title as topic_title, #{Forum.table_name}.name as forum_name", :joins => "inner join #{Topic.table_name} on #{Post.table_name}.topic_id = #{Topic.table_name}.id inner join #{Forum.table_name} on #{Topic.table_name}.forum_id = #{Forum.table_name}.id" }

	# @WBH@ TODO: This uses the caches_formatted_page method.  In the main Beast project, this is implemented via a Config/Initializer file.  Not
	# sure what analogous place to put it in this plugin.  It don't work in the init.rb
  #caches_formatted_page :rss, :index, :monitored
  
  def index
#    conditions = []
#    [:user_id, :forum_id, :topic_id].each { |attr| conditions << Post.safe_send(:sanitize_sql, ["#{Post.table_name}.#{attr} = ?", params[attr]]) if params[attr] }
#    conditions << Post.safe_send(:sanitize_sql, ["#{Post.table_name}.account_id = ?", current_account.id]) #by Shan temp
#    conditions = conditions.empty? ? nil : conditions.collect { |c| "(#{c})" }.join(' AND ')
#    #@posts = Post.paginate @@query_options.merge(:conditions => conditions, :page => params[:page], :count => {:select => "#{Post.table_name}.id"}, :order => post_order, :limit =>10 )
#    @posts = Post.find(:all,:conditions => conditions, :order => post_order, :limit =>10 )
#    @users = current_account.users.find(:all, :select => 'distinct *', :conditions => ['id in (?)', @posts.collect(&:user_id).uniq]).index_by(&:id)
#    render_posts_or_xml
  end

  # PRE-RAILS: Not found in routes.rb, need to check
  def monitored
    @user = current_account.users.find params[:user_id]
    options = @@query_options.merge(:conditions => ["#{Monitorship.table_name}.user_id = ? and #{Post.table_name}.user_id != ? and #{Monitorship.table_name}.active = ?", params[:user_id], @user.id, true])
    options[:order]  = post_order
    options[:joins] += " inner join #{Monitorship.table_name} on #{Monitorship.table_name}.topic_id = #{Topic.table_name}.id"
    options[:count]  = {:select => "#{Post.table_name}.id"}
    @posts = Post.joins(options[:joins]).where(options[:conditions]).select(options[:select]).order(options[:order]).count(options[:count]).paginate(page: params[:page])
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
    if @topic.locked?
      respond_to do |format|
        format.html do
          flash[:notice] = 'This topic is locked.'
          redirect_to(category_forum_topic_path(:category_id => params[:category_id],:forum_id => params[:forum_id], :id => params[:topic_id]))
        end
        format.xml do
          render :text => 'This topic is locked.', :status => 400
        end
      end
      return
    end
    
    @forum = @topic.forum
    @post  = @topic.posts.build(params[:post])
    if privilege?(:admin_tasks)
      @post.user = (params[:post][:import_id].blank? || params[:email].blank?) ? current_user : current_account.all_users.find_by_email(params[:email]) 
    end
    @post.user ||= current_user
    @post.account_id = current_account.id
    build_attachments
    @post.save
    respond_to do |format|
      format.html do
        redirect_to category_forum_topic_path(:category_id => params[:category_id],:forum_id => params[:forum_id], :id => params[:topic_id], :anchor => @post.dom_id, :page => params[:page] || '1')
      end
      format.xml { render :xml => @post }
      format.json { render :json => @post,:status=>:created}
    end
  rescue ActiveRecord::RecordInvalid
    flash[:bad_reply] = 'Please post a valid message...'
    respond_to do |format|
      format.html do
        redirect_to category_forum_topic_path(:category_id => params[:category_id],:forum_id => params[:forum_id], :id => params[:topic_id], :anchor => 'reply-form', :page => params[:page] || '1')
      end
      format.xml { render :xml => @post.errors.to_xml, :status => 400 }
    end
  end
  
  def build_attachments
    attachment_builder(@post, params[:post][:attachments], params[:cloud_file_attachments], params[:attachments_list])
  end
  
  def edit
    render :partial => "edit"
  end
  
  def update
    @post.attributes = params[:post]
    @post.save
    rescue ActiveRecord::RecordInvalid
      flash[:bad_reply] = 'An error occurred'
    ensure
      respond_to do |format|
        format.html do
          redirect_to category_forum_topic_path(@post.topic.forum.forum_category_id,:forum_id => params[:forum_id], :id => params[:topic_id])
        end
        format.js
        format.xml { head 200 }
        format.json { head 200 }
      end
  end

  def destroy
    @post.destroy
    flash[:notice] = (I18n.t('flash.post.deleted', :title => h(@post.topic.title))).html_safe
    respond_to do |format|
      format.html do
        redirect_to(@post.topic.frozen? ? 
          category_forum_path(@post.topic.forum.forum_category_id,:forum_id => params[:forum_id]) :
          category_forum_topic_path(@post.topic.forum.forum_category_id,:forum_id => params[:forum_id], :id => params[:topic_id]))
      end
      format.xml { head 200 }
      format.json { head 200 }
    end
  end
  
  def toggle_answer
    @post.toggle_answer
    respond_to do |format| 
        format.html { redirect_to category_forum_topic_path(params[:category_id],params[:forum_id], params[:topic_id]) }
        format.xml  { head :created, :location => topic_url(:forum_id => @forum, :id => @topic, :format => :xml) }
      end
  end

  def best_answer
    @answer = @topic.answer
    render :partial => "forum_shared/best_answer"
  end

  protected
#    def authorized? #Commented by Shan
#      action_name == 'create' || @post.editable_by?(current_user)
#    end
    
    def post_order
      "#{Post.table_name}.created_at#{params[:forum_id] && params[:topic_id] ? nil : " desc"}"
    end
    
    def scoper
      current_account.forum_categories
    end
    
    def find_forum_topic
      wrong_portal unless(main_portal? || 
            (params[:category_id].to_i == current_portal.forum_category_id)) #Duplicate

      @forum_category = scoper.find(params[:category_id])
      @forum = @forum_category.forums.find(params[:forum_id])
      @topic = @forum.topics.find(params[:topic_id]) if params[:topic_id]
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

    def RecordNotFoundHandler
      flash[:notice] = I18n.t(:'flash.post.page_not_found')
      redirect_to categories_path
    end
    
end
