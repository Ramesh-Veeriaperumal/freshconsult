module Solution::ArticlesHelper

  include ActionView::Helpers::NumberHelper
  
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
    @current_item ||= @article.draft || @article
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
    return unless privilege?(:delete_solution)
    link_to(  t('solutions.drafts.discard'), 
              solution_draft_delete_path(@article.parent_id, @article.language_id),
              :method => 'delete',
              :confirm => t('solution.articles.draft.discard_confirm'),
              :class => 'draft-btn'
            ) if (@article.published? && @article.draft.present?)
  end

  def publish_link
    return if @article.solution_folder_meta.is_default? or !privilege?(:publish_solution)
    link_to(  t('solutions.drafts.publish'), 
              solution_draft_publish_path(@article.parent_id, @article.language_id),
              :method => 'post', 
              :class => 'draft-btn') if (@article.draft.present? || @article.status == Solution::Article::STATUS_KEYS_BY_TOKEN[:draft])
  end
  
  def form_data_attrs
    return {} if @article.new_record?
    
    {
      :"autosave-path" => solution_draft_autosave_path(@article.parent_id, @article.language_id),
      :timestamp => @article.draft.present? ? @article.draft.updation_timestamp : false,
      :"default-folder" => @article.solution_folder_meta.is_default,
      :"draft-discard-url" => solution_draft_delete_path(@article.parent_id, @article.language_id),
      :"preview-path" => support_draft_preview_path(@article, 'preview'),
      :"preview-text" =>  t('solution.articles.view_draft'),
      :"article-id" => @article.id
    }
  end

  def user_votes_stats count, type, meta_child
    t_type = (type ==  1) ? 'like' : 'dislike'
    content = %(<div class="votes-btn"> #{font_icon(t_type)}&nbsp; #{count} </div>)
    return content.html_safe if count < 1 || !meta_child
    %(
      #{link_to( "<div class=\"votes-btn\"> #{font_icon(t_type)}&nbsp; #{count} </div>".html_safe,
        voted_users_solution_article_path(@article_meta.id, {:vote => type, :language_id => @article.language_id}),
        :rel => "freshdialog",
        :class => "article-#{t_type}",
        :title => t(t_type.pluralize), 
        "data-target" => "#article-#{t_type}",
        "data-template-footer" => "",
        "data-width" => "400px" )}
    ).html_safe
  end

  def company_visibility_tooltip(folder)
    company_names = folder.customers.first(5).map(&:name).join(', ')
    count = folder.customers.size - 5
    company_names += t('solution.folders.visibility.extra_companies', :count => count) if count > 0
    %(<span #{ "class=\"tooltip\" data-placement=\"right\" title=\"#{company_names}\"" if folder.visibility == Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users]}>
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

  def article_properties_edit_link(link_text)
    return unless privilege?(:manage_solutions) || privilege?(:publish_solution)
    link_to( link_text, 
            properties_solution_article_path(@article.parent_id,{:edit => true, :language_id => @article.language_id}),
            :rel => "freshdialog",
            :class => "article-properties",
            :title => t('solution.articles.properties'),
            :data => {
              :target => "#article-prop-#{@article.id}",
              :width => "700px",
              "close-label" => t('cancel'),
              "submit-label" => t('save'), 
              "submit-loading" => t('saving')
            }).html_safe
  end


  def draft_saved_notif_bar
    %(<span> #{t('solution.draft.autosave.save_success')} </span>
      <span title="#{formated_date(@article.draft.updated_at)}" class="tooltip" data-livestamp="#{@article.draft.updation_timestamp}"></span>
      <span class="pull-right">
        #{link_to t('solution.articles.view_draft'), support_draft_preview_path(@article, "preview"),:target => "draft-"+@article.id.to_s}
      </span>).html_safe
  end

  def drafts_present? article
    articles_array = Solution::ArticleMeta.translation_associations.map do |association|
      article.send(association)
    end
    drafts_array = articles_array.compact.select do |a|
      a.draft.present? || a.status == Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]
    end
    @language_ids = drafts_array.map(&:language_id)
    drafts_array.present?
  end

  def formatted_value number
    number_to_human(number, :units => {:thousand => "K", :million => "M", :billion => "B"}).delete(' ')
  end

  def add_new_lang_article(lang_ids)
    return if lang_ids.blank?
    content = []
    lang_ids.each do |lang_id|
      lang = Language.find(lang_id)
      next if lang.blank?
      content << %(<li>)
      content << pjax_link_to( "<span class=\"language_icon\">#{lang.code}</span> #{lang.name}".html_safe, 
                  solution_new_article_version_path(@article_meta.id, lang.code)).html_safe
      content << %(</li>)
    end
    %(<span class="add-new-trans pull-right">
        <div class="drop-right nav-trigger" disabled href="#" menuid="#new-translation">
          #{t('solution.articles.add_translation')}
        </div>
        <div class="fd-menu" id="new-translation">
          <ul> #{content.join('')}</ul>
        </div>
      </span>).html_safe
  end
  
end
