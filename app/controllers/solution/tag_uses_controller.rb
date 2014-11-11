class Solution::TagUsesController < ApplicationController
  def index
  end

  def show
  end

  def new
  end

  def edit
  end

  def create
  end

  def update
  end

  def destroy
    
    article = Solution::Article.find_by_id_and_account_id(params[:article_id], current_account)
    logger.debug "article is #{article.inspect}"
    raise ActiveRecord::RecordNotFound unless article

    tag = article.tags.find_by_id(params[:id])
    raise ActiveRecord::RecordNotFound unless tag

    taggable_type = params[:taggable_type] || "Solution::Article"
    # ticket.tags.delete(tag) does not call tag_use.destroy, so it won't 
    # decrement the counter cache. This is a workaround. need to re-work..now this will work only for ticket module
    
    Helpdesk::TagUse.find_by_taggable_id_and_tag_id_and_taggable_type(article.id, tag.id,taggable_type ).destroy
    #TODO-Rails3 - We may have to remove the below 2 lines for the functionality to work.
    count = tag.tag_uses_count - 1
    tag.update_attribute(:tag_uses_count,count )

    flash[:notice] = t(:'flash.solutions.remove_tag.success')
    redirect_to :back
  end

end
