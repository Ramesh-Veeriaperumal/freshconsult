#To Do Shan - Need to use ModelController or HelpdeskController classes, instead of
#writing/duplicating all the CRUD methods here.
class ForumsController < ApplicationController 
  #before_filter :login_required, :except => [:index, :show]
  before_filter :except => [:index, :show] do |c| 
    c.requires_permission :manage_forums
  end
  before_filter { |c| c.requires_feature :forums }
  before_filter :find_or_initialize_forum, :except => :index
  before_filter :admin?, :except => [:show, :index]
  before_filter :set_selected_tab

  cache_sweeper :posts_sweeper, :only => [:create, :update, :destroy]

  def index
   @forum_categories = scoper.all
     respond_to do |format|
      format.html 
      format.xml  { render :xml => @forum_categories }
      format.json  { render :json => @forum_categories }
      format.atom 
    end
  end

  def show
   
   (session[:forums] ||= {})[@forum.id] = Time.now.utc if logged_in?
   (session[:forum_page] ||= Hash.new(1))[@forum.id] = params[:page].to_i if params[:page]

    if @forum.ideas? and params[:order].blank?
      conditions =  {:stamp_type => params[:stamp_type]} unless params[:stamp_type].blank?
      @topics = @forum.topics.find(:all, :include => :votes, :conditions => conditions).sort_by { |u| -u.votes.size }
    else
      params[:order] = "created_at" if params[:order].blank? 
      params[:order] = params[:order] + " desc";
      @topics = @forum.topics
    end
    
    @topics = @topics.paginate(
          :page => params[:page], 
          :order => params[:order],
          :per_page => 10)
    
    #@topics = @topics.paginate :page => params[:page]
    
    
    
    respond_to do |format|
      format.html do
        # keep track of when we last viewed this forum for activity indicators
         end
      format.xml  { render :xml => @forum.to_xml(:include => :topics) }
      format.json  { render :json => @forum.to_json(:include => :topics) }
      format.atom
    end
  end

  # new renders new.html.erb  
  def create
    @forum = @forum_category.forums.build(params[:forum])
    @forum.account_id ||= current_account.id
    if @forum.save
      respond_to do |format|
        format.html { redirect_to(category_forum_path( @forum_category,@forum), :notice => 'The forum has been created.') }
        format.xml  { render :xml => @forum,:status => 200 }
      end
    else
      respond_to do |format|
        format.html {  render :action => 'new' }
        format.xml  {  render :xml => @forum.errors ,:status => 500}
      end
     
    end
  end

  def update
    if @forum.update_attributes(params[:forum])
      respond_to do |format|
        format.html { redirect_to category_forum_path(@forum_category,@forum) }
        format.xml  { head 200 }
      end
    else
      format.html {render :action => 'edit'}
      format.xml  {render :xml => @forum.errors }
    end
  end
  
  
  
  def destroy
    @forum.destroy
    respond_to do |format|
      format.html { redirect_to categories_path }
      format.xml  { head 200 }
    end
  end
  
  def scoper
    current_account.forum_categories
  end
  
  protected
    def find_or_initialize_forum # Shan - Should split-up find & initialize as separate methods.
      @forum_category = params[:category_id] ? scoper.find(params[:category_id]) : nil
      @forum = params[:id] ? @forum_category.forums.find(params[:id]) : nil
   end
    
    def set_selected_tab
      @selected_tab = 'Forums'
    end

    alias authorized? admin?
end
