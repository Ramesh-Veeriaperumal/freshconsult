#To Do Shan - Need to use ModelController or HelpdeskController classes, instead of
#writing/duplicating all the CRUD methods here.
class ForumsController < ApplicationController

  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:index, :show]
  before_filter :portal_check, :only => [:index, :show]

  include Helpdesk::ReorderUtility

  rescue_from ActiveRecord::RecordNotFound, :with => :RecordNotFoundHandler

  before_filter { |c| c.requires_feature :forums }
  before_filter { |c| c.check_portal_scope :open_forums }
  before_filter :find_or_initialize_forum, :except => :index
  before_filter :set_selected_tab
  before_filter :fetch_monitorship, :only => :show

  def index
    redirect_to discussions_path
  end

  def show
   (session[:forums] ||= {})[@forum.id] = Time.now.utc
   (session[:forum_page] ||= Hash.new(1))[@forum.id] = params[:page].to_i if params[:page]

    if @forum.stamps? and params[:order].blank?
      conditions =  {:stamp_type => params[:stamp_type]} unless params[:stamp_type].blank?
      @topics = @forum.topics.published.includes(:votes).where(conditions).to_a.sort_by { |u| [-u.sticky, -u.votes.size] }
    else
      params[:order] = "created_at" if params[:order].blank?
      params[:order] = params[:order] + " desc" unless params[:order].include?("desc")
      params[:order] = "sticky desc, #{params[:order]}"
      @topics = @forum.topics.published.order(params[:order]).to_a
    end

    @topics = @topics.paginate(
          :page => params[:page],
          :per_page => 10)

    respond_to do |format|
      format.html do
        redirect_to discussions_forum_path(@forum)
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
        format.html { redirect_to(discussions_forum_path(@forum), :notice => I18n.t('forum.forum_created')) }
        format.xml  { render :xml => @forum,:status => 200 }
        format.json  { render :json => @forum,:status => :created }
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
        format.html { redirect_to discussions_forum_path(@forum) }
        format.xml  { head 200 }
        format.json { head 200 }
      end
    else
     respond_to do |format|
      format.html {render :action => 'edit'}
      format.xml  {render :xml => @forum.errors }
     end
    end
  end

  def new
    respond_to do |format|
      format.html { redirect_to new_discussions_forum_path }
      format.xml  { render :xml => @forum }
    end
  end

  def destroy
    @forum.backup_forum_topic_ids
    @forum.destroy
    respond_to do |format|
      format.html { redirect_to discussions_path }
      format.xml  { head 200 }
      format.json { head 200 }
    end
  end

  def edit
    redirect_to edit_discussions_forum_path(@forum)
  end

  protected

    def scoper
      current_account.forum_categories
    end

    def reorder_scoper
      scoper.find(params[:category_id]).forums
    end

    def fetch_monitorship
      @monitorship = @forum.monitorships.where(['user_id = ? and active = ?', current_user.id, true]).count
    end

    def reorder_redirect_url
      discussion_path(params[:category_id])
    end

    def find_or_initialize_forum # Shan - Should split-up find & initialize as separate methods.
      if params[:category_id]
        wrong_portal unless(main_portal? ||
              (params[:category_id].to_i == current_portal.forum_category_id)) #Duplicate
      end

      @forum_category = params[:category_id] ? scoper.find(params[:category_id]) : nil
      @forum = params[:id] ? @forum_category.forums.find(params[:id]) : nil
    end

    def set_selected_tab
      @selected_tab = :forums
    end

    def RecordNotFoundHandler
      flash[:notice] = I18n.t(:'flash.forum.page_not_found')
      redirect_to discussions_path
    end

  private

    def portal_check
      if current_user.nil? || current_user.customer?
        @forum = params[:id] ? current_account.portal_forums.find(params[:id]) : nil
        return redirect_to support_discussions_forum_path(@forum)
      elsif !privilege?(:view_forums)
        access_denied
      end
    end
end
