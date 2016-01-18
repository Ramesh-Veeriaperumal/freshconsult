class Helpdesk::TagsController < ApplicationController
  helper Helpdesk::TicketsHelper

  before_filter :set_selected_tab, :check_admin_user_privilege

  include HelpdeskControllerMethods

  def index

    tag_id = params[:tag_id].present? ? [params[:tag_id]] : :all
    sort_order = params[:sort] || cookies[:tag_sort_key] || :activity_desc 
    
    @tags = Helpdesk::Tag.sort_tags(sort_order).tag_search(params["name"]).find(tag_id).paginate(
        :page => params[:page],
        :include => [:tag_uses],
        :per_page => 50)

    cookies[:tag_sort_key] = sort_order;
    if params[:sort].present? and params[:page].blank?
      render :partial => "sort_results"
    end

  end

  def rename_tags
    tag = Helpdesk::Tag.find(params[:tag_id])
    same_name_tags = Helpdesk::Tag.count(:all, :conditions => ["name = ? and id != ?", params[:tag_name], params[:tag_id]])
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
    tag_uses = Helpdesk::TagUse.find_all_by_taggable_type(params[:tag_type], :conditions => ["tag_id = ? ", params[:tag_id]])
    tag_uses.each {|t| t.destroy}
    render :json => {:tag_uses_removed_count => tag_uses.size }
  end


  def autocomplete #Ideally account scoping should go to autocomplete_scoper -Shan
    items = autocomplete_scoper.find(
        :all,
        :conditions => ["name like ?", "#{params[:v]}%"],
        :limit => 30)

    r = {:results => items.map {|i| {:id => autocomplete_id(i), :value => i.send(autocomplete_field)} } }

    respond_to do |format|
      format.json { render :json => r.to_json }
    end
  end

  def check_admin_user_privilege
    if !(current_user and  current_user.privilege?(:admin_tasks))
      flash[:notice] = t('flash.general.access_denied')
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) 
    end
  end 

  protected
  
   def set_selected_tab
      @selected_tab = :admin
   end


end
