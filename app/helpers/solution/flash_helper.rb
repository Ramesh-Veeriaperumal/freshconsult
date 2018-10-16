module Solution::FlashHelper

  def flash_message
    unless language_visible_in_portal? @article
      msg = ["#{t('solution.articles.published_success_msg')}"]
    else
      msg = ["#{t('solution.articles.published_success_not_in_portal')}"]
    end

    if current_account.multilingual?
      if @article.is_primary? && !@article_meta.all_versions_outdated?
        msg << mark_as_outdate_uptodate('outdated')
      elsif !@article.is_primary? && @article.outdated?
        msg << mark_as_outdate_uptodate('uptodate')
      end
    end
    msg << view_on_portal_link
    msg.compact.join(' - ').html_safe
  end

  def view_on_portal_link
    return unless @article_meta.solution_category_meta.present? && @article_meta.solution_category_meta.portal_ids.present?
    unless language_visible_in_portal? @article
      relative_path = support_solutions_article_path(@article, view_context.path_url_locale)
      publish_link_html(
        view_context.article_path(relative_path, @article_meta.solution_folder_meta.solution_category_meta),
        t('solution.view_on_portal')
      )
    else
      portal_add_language_link @article
    end
  end

  def portal_add_language_link article
    if privilege?(:admin_tasks)
      publish_link_html(manage_languages_path, t('solution.articles.change_language_settings', :language_name => article.language.name))
    else
      t('solution.articles.contact_admin').html_safe
    end
  end

  def publish_link_html path, msg
    "<a href=#{path} target = '_blank'> 
      #{msg}
    </a>"
  end

  def mark_as_outdate_uptodate action_type
    "<a href='#' 
        class='outdate-uptodate' 
        data-action-type='mark-#{action_type}' 
        data-item-id='#{@article_meta.id}' 
        data-url='#{safe_send("mark_as_#{action_type}_solution_articles_path")}' 
        data-language-id='#{@article.language_id}'
      > #{t("solution.general.mark_as_#{action_type}.text_1")}</a> | "
  end

  def language_visible_in_portal? article
    Account.current.multilingual? && !Account.current.all_portal_language_objects.include?(article.language)
  end
end
