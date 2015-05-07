module Solution::ArticlesHelper
  
  def breadcrumb
    output = []
    output << pjax_link_to(t('solution.title'), solution_categories_path)
    if @article.folder.is_default?
      output << pjax_link_to(t('solution.draft.name'), solution_drafts_path)
    else
      output << pjax_link_to(@article.folder.category.name, solution_category_path(@article.folder.category))
      output << pjax_link_to(@article.folder.name, solution_category_folder_path(@article.folder.category_id, @article.folder))
    end
    output.join(' ').html_safe
  end
  
  def language_tabs
    %{
      <a href="/" class="active"><span>English</span></a>
      <a href="/" class="red"><span>Latin</span></a>
      <a href="/" class="grey"><span>Spanish</span></a>
      <a href="/">French</a>
    }.html_safe
  end
  
  def draft_info_text
    if @article.draft and @article.draft.locked?
      t('solution.articles.restrict_edit', :name => h(current_item.user.name)).html_safe
    else
      [
        t('solution.articles.draft.show_page_msg'),
        (current_user == current_item.user) ? t('solution.articles.draft.you') : current_item.user.name,
        "<span data-livestamp='#{current_item.modified_at.to_i}' class='tooltip' title='#{formated_date(current_item.modified_at)}'></span>"
      ].join('').html_safe
    end
  end
  
  def discard_link
    link_to(t('solutions.drafts.discard'), solution_article_draft_path(@article, @article.draft), 
              :method => 'delete',
              :confirm => t('solution.articles.draft.discard_confirm')
            ) if @article.published? and @article.draft.present?
  end
  
end
