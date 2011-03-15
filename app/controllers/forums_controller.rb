#To Do Shan - Need to use ModelController or HelpdeskController classes, instead of
#writing/duplicating all the CRUD methods here.
class ForumsController < ApplicationController 
  #before_filter :login_required, :except => [:index, :show]
  before_filter :except => [:index, :show] do |c| 
    c.requires_permission :manage_forums
  end
  before_filter :find_or_initialize_forum, :except => :index
  before_filter :admin?, :except => [:show, :index]
  before_filter :set_selected_tab

  cache_sweeper :posts_sweeper, :only => [:create, :update, :destroy]

  def index
    @forums = Forum.find_ordered(current_account)
    # reset the page of each forum we have visited when we go back to index
    session[:forum_page] = nil
    respond_to do |format|
      format.html
      format.xml { render :xml => @forums }
    end
  end

  def show
    @forum_category = ForumCategory.find(params[:category_id])
    @forum = Forum.find(params[:id])
    
   (session[:forums] ||= {})[@forum.id] = Time.now.utc if logged_in?
   (session[:forum_page] ||= Hash.new(1))[@forum.id] = params[:page].to_i if params[:page]

    @topics = @forum.topics.paginate :page => params[:page]
    User.find(:all, :conditions => ['id IN (?)', @topics.collect { |t| t.replied_by }.uniq]) unless @topics.blank?
    
   
    respond_to do |format|
      format.html do
        # keep track of when we last viewed this forum for activity indicators
         end
      format.xml { render :xml => @forum.to_xml(:include => [:forum_category,:topics] )   }
      format.atom
    end
  end

  # new renders new.html.erb  
  def create
    #@forum.attributes = params[:forum]
    @forum_category = ForumCategory.find(params[:category_id])
    @forum = @forum_category.forums.build(params[:forum])
    @forum.account_id ||= current_account.id
    if @forum.save
      respond_to do |format|
        format.html { redirect_to(category_forum_path( @forum_category,@forum), :notice => 'The forum has been created.') }
        format.xml  { head :created, :location => category_forum_path( @forum_category,@forum, :format => :xml) }
      end
    else
      render :action => 'new'
    end
  end

  def update
    if @forum.update_attributes(params[:forum])
      respond_to do |format|
        format.html { redirect_to @forum }
        format.xml  { head 200 }
      end
    else
      render :action => 'edit'
    end
  end
  
  def new
    @forum_category = ForumCategory.find(params[:category_id])
  end
  
  def destroy
    @forum.destroy
    respond_to do |format|
      format.html { redirect_to forums_path }
      format.xml  { head 200 }
    end
  end
  
  protected
    def find_or_initialize_forum # Shan - Should split-up find & initialize as separate methods.
      @forum = params[:id] ? Forum.find(params[:id]) : Forum.new
      @forum.account_id ||= current_account.id
      (raise(ActiveRecord::RecordNotFound) unless (@forum.account_id == current_account.id)) || @forum
    end
    
    def set_selected_tab
      @selected_tab = 'Forums'
    end

    alias authorized? admin?
end
