module Solution::FlashHelper

  def flash_message
    msg = t('solution.articles.published_success_msg')
    if @article.is_primary? && !@article_meta.all_versions_outdated?
      msg << mark_as_outdate_uptodate('outdated')
    elsif !@article.is_primary? && @article.outdated?
      msg << mark_as_outdate_uptodate('uptodate')
    end
    msg << view_on_portal_link
    msg.html_safe
  end

  def view_on_portal_link
    "<a href=#{support_solutions_article_path(@article, :url_locale => @article.language.code)}
        target = '_blank'
      > #{t('solution.view_on_portal')}
    </a>"
  end

  def mark_as_outdate_uptodate action_type
    "<a href='#' 
        class='outdate-uptodate' 
        data-action-type='mark-#{action_type}' 
        data-item-id='#{@article_meta.id}' 
        data-url='#{send("mark_as_#{action_type}_solution_articles_path")}' 
        data-language-id='#{@article.language_id}'
      > #{t("solution.general.mark_as_#{action_type}")}</a>"
  end
end