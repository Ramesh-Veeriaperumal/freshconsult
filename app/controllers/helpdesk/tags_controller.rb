class Helpdesk::TagsController < ApplicationController
  helper Helpdesk::TicketsHelper

  before_filter :set_selected_tab, :check_manage_tags_privilege

  include HelpdeskControllerMethods

  TAGS_PER_PAGE_LIMIT = 10

  def create
    tag_name = params[:name]
    if scoper.where(name: tag_name).blank?
      @new_tag = scoper.create(name: tag_name)
    else
      flash.now[:notice] = t('tag_exists')
    end
    respond_to do |format|
      format.js { }
    end
  end

  def index
    sort_order = params[:sort] || cookies[:tag_sort_key] || :activity_desc
    @archive_feature = current_account.features_included?(:archive_tickets)
    @tags = if params[:tag_id].blank?
              Helpdesk::Tag.sort_tags(sort_order).tag_search(params['name']).paginate(page: params[:page], per_page: TAGS_PER_PAGE_LIMIT).to_a
            else
              Helpdesk::Tag.sort_tags(sort_order).tag_search(params['name']).where(id: params[:tag_id]).paginate(page: 1, per_page: TAGS_PER_PAGE_LIMIT).to_a
            end
    cookies[:tag_sort_key] = sort_order

    render partial: 'sort_results' if params[:sort].present? && params[:page].blank?
  end

  def rename_tags
    tag = Helpdesk::Tag.find(params[:tag_id])
    same_name_tags = Helpdesk::Tag.where(['name = ? and id != ?', params[:tag_name], params[:tag_id]]).count
      if same_name_tags > 0
        stat = "existing_tag"
      else
        stat = "success"
        tag.update_attribute(:name, params[:tag_name])
      end
    render :json => {:status => stat, :name => tag.name }
  end

  def merge_tags
    tag = Helpdesk::Tag.find(params[:tag_id])
    tag_to_merge = Helpdesk::Tag.find_by_name( params[:tag_name], :conditions => ["id != ?", params[:tag_id]])
    tag_to_merge.tag_uses << tag.tag_uses
    tag_to_merge.save
    tag.destroy
    render :nothing => true
  end

  def remove_tag
    args = { taggable_type: params[:tag_type], tag_id: params[:tag_id] }
    tag_uses_count = Account.current.tag_uses.where(args).count
    args[:doer_id] = User.current.id
    TagUsesCleaner.perform_async(args) unless tag_uses_count.zero?
    render :json => {:tag_uses_removed_count => tag_uses_count }
  end


  def autocomplete #Ideally account scoping should go to autocomplete_scoper -Shan
    items = autocomplete_scoper.where(['name like ?', "#{params[:v]}%"]).limit(30).all.to_a

    r = {:results => items.map {|i| {:id => autocomplete_id(i), :value => i.safe_send(autocomplete_field)} } }

    respond_to do |format|
      format.json { render :json => r.to_json }
    end
  end

  def check_manage_tags_privilege
    if !(current_user and  current_user.privilege?(:manage_tags))
      flash[:notice] = t('flash.general.access_denied')
      redirect_to safe_send(Helpdesk::ACCESS_DENIED_ROUTE) 
    end
  end 

  protected
  
   def set_selected_tab
      @selected_tab = :admin
   end

   def after_destroy_url
      helpdesk_tags_url
   end
   
   def scoper
    current_account.tags
   end

end
