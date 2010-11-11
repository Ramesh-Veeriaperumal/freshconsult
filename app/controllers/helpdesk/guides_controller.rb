class Helpdesk::GuidesController < ApplicationController
  layout 'helpdesk/default'

  before_filter { |c| c.requires_permission :manage_knowledgebase }

  include HelpdeskControllerMethods

  before_filter :load_item, :only => [:show, :edit, :update, :reorder_articles, :privatize, :publicize]

  uses_tiny_mce :options => Helpdesk::EDITOR_OPTIONS 

  def index
    @items = Helpdesk::Guide.display_order.all(:conditions => { :account_id => current_account.id })
  end

  def show
    @articles = @item.articles.display_order.all(:conditions => { :account_id => current_account.id })
  end

  def reorder
    i = 0
    params[:order].split(',').each do |guide_id| 
      s = Helpdesk::Guide.find(guide_id)
      if s
        s.position = i
        i += 1
        s.save
      end
    end

    redirect_to helpdesk_guides_path
  end


  def reorder_articles
    i = 0
    params[:order].split(',').each do |article_id| 
      as = @guide.article_guides.find_by_article_id(article_id)
      if as
        as.position = i
        i += 1
        as.save
      end
    end

    redirect_to helpdesk_guide_path(@item)
  end

  def privatize
    @guide.update_attribute(:hidden, true)
    flash[:notice] = "The guide was made private"
    redirect_to :back
  end
    
  def publicize
    @guide.update_attribute(:hidden, false)
    flash[:notice] = "The guide was made public"
    redirect_to :back
  end

protected

  def after_destroy_url
    helpdesk_guides_url
  end

  def item_url
    return new_helpdesk_guide_path if params[:save_and_create]
    @item
  end

end
