module Solution::ArticlesHelper

  include Solution::LanguageTabsHelper
  include HumanizeHelper

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
              :class => 'draft-btn draft-btn-publish') if (current_account.verified? && (@article.draft.present? || @article.status == Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]))
  end

  def form_data_attrs
    return {
      :"new-article" => true
    } if @article.new_record?

    {
      :"autosave-path" => solution_draft_autosave_path(@article.parent_id, @article.language_id),
      :timestamp => @article.draft.present? ? @article.draft.updation_timestamp : false,
      :"default-folder" => @article.solution_folder_meta.is_default,
      :"draft-discard-url" => solution_draft_delete_path(@article.parent_id, @article.language_id),
      :"preview-path" => draft_portal_preview,
      :"preview-text" =>  t('solution.articles.view_draft'),
      :"article-id" => @article.id,
      :"orphan-category" => orphan_category?
    }
  end

  def user_votes_stats count, type, meta_child
    t_type = (type ==  1) ? 'like' : 'dislike'
    content = %(<div class="votes-btn"> #{font_icon(t_type)}#{humanize_stats(count)} </div>)
    return content.html_safe if count < 1 || !meta_child
    %(
      #{link_to( "<div class=\"votes-btn\"> #{font_icon(t_type)}#{humanize_stats(count)} </div>".html_safe,
        voted_users_solution_article_path(@article_meta.id, {:vote => type, :language_id => @article.language_id}),
        :rel => "freshdialog",
        :class => "article-#{t_type}",
        :title => t(t_type.pluralize),
        "data-target" => "#article-#{t_type}",
        "data-template-footer" => "",
        "data-width" => "400px" )}
    ).html_safe
  end

  def company_visibility_tooltip(folder_meta)
    span_attributes = ""
    if folder_meta.has_company_visiblity?
      company_names = folder_meta.customers.first(5).map(&:name).join(', ')
      count = folder_meta.customers.size - 5
      company_names += t('solution.folders.visibility.extra_companies', :count => count) if count > 0
      span_attributes = "class='tooltip' data-placement='right' title='#{h(company_names)}'"
    end
    %(<span #{ span_attributes }>
        #{ folder_meta.visibility_type }
      </span>).html_safe
  end

  def created_at_ellipsis?
    @article.published? && @article.modified_at.present? && (@article.created_at != @article.modified_at)
  end

  def cancel_btn_link
    return solution_article_path(@article_meta.id) if @article_meta.present? && !@article_meta.new_record? && @article.new_record?
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
    output << submit_tag(t('solution.articles.publish'), :name => "publish", :class => "btn btn-primary", :id => publish_btn || "article-publish-btn", :"data-target-btn" => "#article-publish-btn", :disabled => !current_account.verified?)
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
        #{link_to t('solution.articles.view_draft'), draft_portal_preview, :target => "draft-"+@article.id.to_s unless orphan_category?}
      </span>).html_safe
  end

  def not_in_portal_notification article
    if Account.current.multilingual? && !Account.current.all_portal_language_objects.include?(article.language)
      op = ""
      op << %(<div class="not-in-portal">)
      op << t('solution.articles.language_not_in_portal') + " - "
      if privilege?(:admin_tasks)
        op << (current_user.is_falcon_pref? ? link_to(t('solution.articles.change_language_settings', :language_name => article.language.name), '/a/admin/account/languages', :target => '_top', :id => 'manage-account-languages')
              : pjax_link_to(t('solution.articles.change_language_settings', :language_name => article.language.name), manage_languages_path) )
      else
        op << t('solution.articles.contact_admin').html_safe
      end
      op << %(</div>)
      op.html_safe
    end
  end

  def missing_translations? article
    return false unless Account.current.multilingual?
    !(article.solution_folder_meta.safe_send("#{article.language.to_key}_available?") && article.parent.solution_category_meta.safe_send("#{article.language.to_key}_available?"))
  end

  def draft_portal_preview
    portal_article_path(support_draft_preview_path(@article, 'preview', path_url_locale), @article.solution_folder_meta.solution_category_meta, true)
  end

  def orphan_category?
    category = @article.solution_folder_meta.solution_category_meta
    return true if category.present? && category.portal_ids.empty?
  end
end
