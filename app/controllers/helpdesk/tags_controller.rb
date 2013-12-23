class Helpdesk::TagsController < ApplicationController
  helper 'helpdesk/tickets'

  before_filter :set_selected_tab

  include HelpdeskControllerMethods

  def index

    tag_id = params[:tag_id].present? ? [params[:tag_id]] : :all
    @tags = Helpdesk::Tag.sort_tags(params[:sort] || :activity_desc).tag_search(params["name"]).find(tag_id).paginate(
        :page => params[:page],
        :include => [:tag_uses],
        :per_page => 50)

    if params[:sort].present? and params[:page].blank?
      render :partial => "sort_results"
    end

  end

  def rename_tags
    tag = Helpdesk::Tag.find(params[:tag_id])
    primary_tag = 0
    same_name_tags = Helpdesk::Tag.find_all_by_name( params[:tag_name], :conditions => ["id != ?", params[:tag_id]])
      if same_name_tags.size > 0
        stat = "existing_tag"
        primary_tag = same_name_tags.first.id
      else
        stat = "success"
        tag.update_attribute(:name, params[:tag_name].gsub(",",""))
      end
    render :json => {:status => stat, :name => tag.name, :primary_tag => primary_tag }
  end

  def merge_tags

    primary_tag = Helpdesk::Tag.find(params[:primary_tag])
    params[:tags_to_merge].delete(primary_tag.id)
    tags_to_merge = params[:tags_to_merge].uniq
    if !tags_to_merge.empty?
    params[:tags_to_merge].each do |t|
      tag = Helpdesk::Tag.find(t)
      primary_tag.tag_uses << tag.tag_uses
      tag.destroy
    end
    primary_tag.save
    end
    render :nothing => true
  end

  def remove_tag
    tag_uses = Helpdesk::TagUse.find_all_by_taggable_type(params[:tag_type], :conditions => ["tag_id = ? ", params[:tag_id]])
    tag_uses.each {|t| t.destroy}
    tag_count = Helpdesk::Tag.find(params[:tag_id]).tag_uses_count
    render :json => {:tag_usage_count => tag_count }
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



  def bulk_merge

  end

  protected
  
   def set_selected_tab
      @selected_tab = :admin
   end


end
