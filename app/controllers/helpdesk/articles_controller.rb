class Helpdesk::ArticlesController < ApplicationController 
  helper 'helpdesk/tickets'
  
  before_filter { |c| c.requires_permission :manage_knowledgebase }
  before_filter :save_referer, :only => [:new, :edit]

  include HelpdeskControllerMethods

  before_filter :add_to_history, :only => [:edit]

  uses_tiny_mce :options => Helpdesk::EDITOR_OPTIONS 

  def index
    @items = Helpdesk::Article.search(Helpdesk::Article.all(:conditions => { :account_id => current_account.id }), params[:f], params[:v])

    @items = @items.paginate( 
      :page => params[:page], 
      :order => Helpdesk::Article::SORT_SQL_BY_KEY[(params[:sort] || :created_desc).to_sym],
      :per_page => 20)
  end

  def show
    redirect_to edit_helpdesk_article_path(@item)
  end

protected

  def save_referer
    session[:article_referer] ||= request.referer
  end

  def referer
    r, session[:article_referer] = session[:article_referer], nil
    r
  end

  def autocomplete_field
    "title"
  end

  def after_destroy_url
    helpdesk_articles_url
  end

  def item_url
    return new_helpdesk_article_path if params[:save_and_create]
    referer || helpdesk_articles_path()
  end

  def process_item
    new_guides = params[:helpdesk_article][:guides] || []

    # Delete guides if they exist in article, but not in params
    # Can't just do @item.guides.clear, because then we would lose
    # the order.
    if @item.guides 
      @item.guides.each do |s|
        unless new_guides.include?(s.id)
          s.article_guides.find_by_article_id(@item.id).destroy
        end
      end
    end

    # Create guides not currently in article but in params
    new_guides.each do |s|
      guide = Helpdesk::Guide.find(s)
      @item.guides << guide if (guide && !@item.guides.exists?(guide))
    end
  end

end
