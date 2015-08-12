module Solution::ArticlesHelper
  
  def breadcrumb
    output = []
    output << pjax_link_to(t('solution.title'), solution_categories_path)
    if @article.folder.is_default?
      output << pjax_link_to(t('solution.draft.name'), solution_drafts_path)
    else
      output << pjax_link_to(@article.folder.category.name, solution_category_path(@article.folder.category))
      output << pjax_link_to(@article.folder.name, solution_folder_path(@article.folder))
    end
    output.join(' ').html_safe
  end
  
  def language_tabs
    %{<div class="tab">
        <a href="/" class="active"><span>English</span></a>
        <a href="/" class="red"><span>Latin</span></a>
        <a href="/" class="grey"><span>Spanish</span></a>
        <a href="/">French</a>
        <a href="javascript:void(0)" class="masterversion-link">Master version</a>
      </div>
    }.html_safe
  end
  
  def draft_info_text
    if @article.draft and @article.draft.locked?
      t('solution.articles.restrict_edit', :name => h(@current_item.user.name)).html_safe
    else
      [
        t('solution.articles.draft.show_page_msg'),
        (current_user == @current_item.user) ? t('solution.articles.draft.you') : @current_item.user.name,
        "<span data-livestamp='#{@current_item.modified_at.to_i}' class='tooltip' title='#{formated_date(@current_item.modified_at)}'></span>"
      ].join(' ').html_safe
    end
  end
  
  def discard_link
    link_to(t('solutions.drafts.discard'), solution_article_draft_path(@article.id, @article.draft), 
              :method => 'delete',
              :confirm => t('solution.articles.draft.discard_confirm'),
              :class => 'draft-btn'
            ) if (@article.published? && @article.draft.present?)
  end

  def publish_link
    return if @article.folder.is_default?
    link_to(t('solutions.drafts.publish'), publish_solution_draft_path(@article), 
              :method => 'post', 
              :class => 'draft-btn') if (@article.draft.present? || @article.status == Solution::Article::STATUS_KEYS_BY_TOKEN[:draft])
  end
  
  def form_data_attrs
    return {} if @article.new_record?
    
    {
      :"autosave-path" => autosave_solution_draft_path(@article.id),
      :timestamp => @article.draft.present? ? @article.draft.updation_timestamp : false,
      :"default-folder" => @article.folder.is_default,
      :"draft-discard-url" => "#{solution_article_draft_path(@article.id, @article.draft.present? ? @article.draft : 1)}",
      :"preview-path" => support_draft_preview_path(@article, 'preview'),
      :"preview-text" =>  t('solution.articles.view_draft')
    }
  end

  def user_votes_stats count, type
    t_type = (type ==  1) ? 'likes' : 'dislikes'
    return "0 #{t(t_type)}" if count < 1
    link_to( "#{count} #{t(t_type)}".html_safe,
            voted_users_solution_article_path(@article, {:vote => type}),
            :rel => "freshdialog",
            :class => "article-#{t_type}",
            :title => t(t_type), 
            "data-target" => "#article-#{t_type}",
            "data-template-footer" => "",
            "data-width" => "400px" 
          ).html_safe
  end

  def company_visibility_tooltip(folder)
    company_names = folder.customers.first(5).map(&:name).join(', ')
    count = folder.customers.size - 5
    company_names += t('solution.folders.visibility.extra_companies', :count => count) if count > 0
    %(<span #{ "class=\"tooltip\" title=\"#{company_names}\"" if folder.visibility == Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users]}>
        #{Solution::Constants::VISIBILITY_NAMES_BY_KEY[folder.visibility]}
      </span>).html_safe
  end

  def created_at_ellipsis?
    @article.published? && @article.modified_at.present? && (@article.created_at != @article.modified_at)
  end

  def cancel_btn_link
    if params[:folder_id].present?
      solution_folder_path(params[:folder_id])
    elsif params[:category_id].present?
      solution_category_path(params[:category_id])
    else
      solution_categories_path
    end
  end

  def article_btns(save_btn = nil, publish_btn = nil)
    output = []
    if @article.new_record?
      output << pjax_link_to(t('cancel'), cancel_btn_link, :class => "btn cancel-button", :id => "edit-cancel-button")
    else
      output << submit_tag(t('cancel'), :class => "btn cancel-button", :id => "edit-cancel-button")
    end
    output << submit_tag(t('save'), :name => "save_as_draft", :class => "btn", :id => save_btn || "save-as-draft-btn", :"data-target-btn" => "#save-as-draft-btn")
    output << submit_tag(t('solution.articles.publish'), :name => "publish", :class => "btn btn-primary", :id => publish_btn || "article-publish-btn", :"data-target-btn" => "#article-publish-btn")
    output.join(' ').html_safe
  end
  
end
