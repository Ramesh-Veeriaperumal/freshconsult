module SolutionHelper
	include Solution::Cache
	include Solution::PathHelper

	def solutions_breadcrumb(page = :home)
		return if page == :home
		_output = []
		_output << pjax_link_to(t('solution.title'), solution_categories_path)
		if page != :all_category && (default_category? || new_article_check?)
			if new_article_check?
				_output << h(t('solution.add_article'))
			else
				_output << pjax_link_to(t('solution.draft.name'), solution_drafts_path)
			end
		else
			case page
				when :category
					_output << truncate(h(@category_meta.name), :length => 120)
				when :folder
					_output << category_link(@folder_meta, page)
					_output << truncate(h(@folder_meta.name), :length => 50)
				when :article
					_output << category_link(@article_meta.solution_folder_meta, page)
					_output << folder_link(@article_meta.solution_folder_meta)
				else
			end
		end
		"<div class='breadcrumb'>#{_output.map{ |bc| "<li>#{bc}</li>" }.join}</div>".html_safe
	end

	def new_article_check?
		@article_meta.present? && @article_meta.new_record?
	end

	def search_placeholder(page)
		case page
			when :category
				t('solution.articles.search_in', :search_scope => @category_meta.name)
			when :folder
				t('solution.articles.search_in', :search_scope => @folder_meta.name)
			else
				t('solution.articles.search_all')
		end
	end

	def default_category?
		category = @category_meta ||
				(@folder_meta && @folder_meta.solution_category_meta) ||
				(@article_meta && @article_meta.solution_folder_meta && @article_meta.solution_folder_meta.solution_category_meta) ||
				{}
		category[:is_default]
	end

	def folder_link folder
		options = { :title => folder.name } if folder.name.length > 40
		pjax_link_to(truncate(folder.name, :length => 40), solution_folder_path(folder.id), (options || {}))
	end

	def category_link(folder, page)
		truncate_length = ( (page == :folder) ? 70 : 40 )
		category_name = folder.solution_category_meta.name
		options = { :title => category_name } if category_name.length > truncate_length
		pjax_link_to(truncate(category_name, :length => truncate_length),
			 			"/solution/categories/#{folder.solution_category_meta.id}", (options || {}))
	end

	def new_solutions_button(default_btn = :article)
		category = [t('solution.add_category'), new_solution_category_path(btn_default_params(:category)), false, new_btn_opts(:category)]
		folder    = [t('solution.add_folder'),    new_solution_folder_path(btn_default_params(:folder)), false, new_btn_opts(:folder)]
		article    = [t("solution.add_article"),    new_solution_article_path(btn_default_params(:article)), false, new_btn_opts(:article)]

		if privilege?(:manage_solutions)
			article = nil unless privilege?(:publish_solution)
			case default_btn
				when :category
					opts = {
						"data-modal-title" => "#{t("solution.add_category")}#{language_label}",
						"data-target" => "#new-cat"
					}
					btn_dropdown_menu(category, [folder, article], opts.merge(default_new_btn_opts))
				when :folder
					opts = {
						"data-modal-title" => "#{t("solution.add_folder")}#{language_label}",
						"data-target" => "#new-fold"
					}
					btn_dropdown_menu(folder, [category, article], opts.merge(default_new_btn_opts))
				else
					opts = { :"data-pjax" => "#body-container" }
					if privilege?(:publish_solution)
						btn_dropdown_menu(article, [category, folder], opts)
					else
						opts = {
							"data-modal-title" => "#{t("solution.add_folder")}#{language_label}",
							"data-target" => "#new-fold"
						}
						btn_dropdown_menu(folder, [category], opts.merge(default_new_btn_opts))
					end
			end
		elsif privilege?(:publish_solution)
			new_article_btn(article)
		else
			""
		end
	end

	def default_new_btn_opts
		{
			:rel => 'freshdialog',
			"data-close-label" => t('cancel'),
			"data-submit-label" => t('save'),
			:"data-pjax" => nil
		}
	end

	def new_btn_opts(type)
		case type
		when :category
			default_new_btn_opts.merge({
				"data-modal-title" => "#{t("solution.add_category")}#{language_label}",
				"data-target" => "#new-cat" })
		when :folder
			default_new_btn_opts.merge({
				"data-modal-title" => "#{t("solution.add_folder")}#{language_label}",
				"data-target" => "#new-fold" })
		when :article
			{ :"data-pjax" => "#body-container", :rel => nil }
		end
	end

	def btn_default_params(type)
		case type
			when :category
				{:portal_id => params[:portal_id]} if params[:portal_id].present?
			when :folder
				{ :category_id => @category_meta.id } if @category_meta.present?
			when :article
				@folder_meta.present? ? ({ :folder_id => @folder_meta.id }) : (@category_meta.present? ? { :category_id => @category_meta.id } : nil)
		end
	end

	def sidebar_toggle
		font_icon("sidebar-list",
								:size => 21,
								:class => "cm-sb-toggle",
								:id => "cm-sb-solutions-toggle").html_safe
	end

	def reorder_btn
		_op = ""
		_op << %(<a href="#" class="btn" id="reorder_btn">
	             #{font_icon "reorder", :size => 13}
	             #{t('reorder')}
					   </a>)
		_op.html_safe
	end

	def helpcard_content(notes, info_base)
		output = []
		notes.each do |num|
			output << %(<p> #{t(info_base + num.to_s).html_safe} </p>)
		end
		output.join("").html_safe
	end

	def portals_for_category(category)
	  content = ""
	  names = category.portals.map{|p| h(p.portal_name) }
	  content << " "
	  if names.present?
			content << names.first(2).join(', ')
			content << %{
				<span
					class="tooltip"
					data-html="true"
					data-placement="right"
					title="#{names[2..-1].join('<br /> ')}">
				...</span>
			} if names.size > 2
			content.html_safe
		else
			content << %{
				<span
					class="muted">
				#{t('solution.unassociated_category')}</span>
				<span
					class="tooltip"
					data-html="true"
					data-placement="right"
					title="#{t('solution.unassociated_category_info')}">
					#{ font_icon('unverified', :size => 16, :class => 'ml2 unassociated-category') }
				</span>
			}
			content.html_safe
		end
	end

	def article_feedback f
		%{<li>
        <div class="sidebar-list-item">
          #{pjax_link_to(t('solution.sidebar.feedbacks.details',
                        :name => f.requester.name.size > 9 ? f.requester.name.truncate(9) : f.requester.name,
                        :time => f.created_at.to_i,
                        :time_string => time_ago_in_words(f.created_at)).html_safe, helpdesk_ticket_path(f))}
	        <span class="feedback-article">
	          #{t('solution.on')}
	          <span title="#{ h(f.article.title) if f.article.title.length > 22 }">#{ h(f.article.title).truncate(25) }</span>
	        </span>
	        <div class="muted">#{ t('solution.sidebar.feedbacks.status', :status => f.status_name) }</div>
	      </div>
      </li>}.html_safe
	end

	def sidebar_drafts a
		%{
			<li class="#{'multilingual_draft' if current_account.multilingual?}">
				#{language_icon(a.article.solution_article_meta, a.article.language) if current_account.multilingual?}
        <div class="sidebar-list-item">
          #{pjax_link_to(h(a.title.truncate(27)),
                          multilingual_article_path(a.article, :anchor => :edit)
                         )}
	        <div class="muted">
	          #{t('solution.sidebar.drafts.details',
	                            :name => truncate(a.user.name, :length => 15),
	                            :time => a.updated_at.to_i,
	                            :time_string => time_ago_in_words(a.updated_at)).html_safe}
					</div>
				</div>
	    </li>
		}.html_safe
	end

	def sidebar_drafts_list(drafts, container_id, active='')
		content = %{<div class='tab-pane sidebar-list #{active}' id="#{container_id}"><ul>}
    drafts_array = drafts.for_sidebar.first(4)
    drafts_array.first(3).each do |draft|
      content << sidebar_drafts(draft)
    end
    content << %{</ul>}
    content << pjax_link_to( t('solution.sidebar.view_all'),
    												drafts_path(container_id), { :class => "view-all"}) if drafts_array.length > 3
		content << %{</div>}
		content.html_safe
	end

	def drafts_path container_id
		container_id == 'drafts-all' ? solution_my_drafts_path('all') : solution_drafts_path
	end

	def sidebar_feedbacks_list(feedbacks, container_id, active='')
		filter = (container_id == 'feedbacks-me') ? 'my_article_feedback' : 'article_feedback'
		content = %{<div class='tab-pane sidebar-list #{active}' id="#{container_id}"><ul>}
    feedbacks_array = feedbacks.first(4)
    # Fetching the first 4, instead of doing a count query
    feedbacks_array.first(3).each do |feedback|
      content << article_feedback(feedback)
    end
    content << %{</ul>}
      if current_user.is_falcon_pref?
		    content << link_to( t('solution.sidebar.view_all'), "/a/tickets/filters/#{filter}",
			             {
			                :class => "view-all article-feedback-list",
			                :"data-parallel-url" => "/helpdesk/tickets/filter_options?filter_name=#{filter}",
			                :"data-parallel-placeholder" => "#ticket-leftFilter"
			             }) if feedbacks_array.length > 3
		  else
		    content << pjax_link_to( t('solution.sidebar.view_all'), "/helpdesk/tickets/filter/#{filter}",
		               {
		                  :class => "view-all",
		                  :"data-parallel-url" => "/helpdesk/tickets/filter_options?filter_name=#{filter}",
		                  :"data-parallel-placeholder" => "#ticket-leftFilter"
		               }) if feedbacks_array.length > 3
		  end
		content << %{</div>}
		content.html_safe
	end

	def option_selector_name identifier
		identifier.delete(' ').underscore
	end

	def dynamic_hidden_fields f
		parent_meta = instance_variable_get("@#{f}_meta")
		op = ""
		op << hidden_field_tag("solution_#{f}_meta[id]", parent_meta.id) if parent_meta && parent_meta.id.present?
		op << hidden_field_tag(:language_id,  @language.id)
		op.html_safe
	end

	def language_flags(solution_meta, article_flag = false)
		return "" unless current_account.multilingual?
		edit = edit_privilege?(solution_meta.class.short_name)
		content = ""
		content << "<div class='span5 pull-right mt8 #{"language-bar" if article_flag} #{'view-links' unless edit}'>"
		content << '<span class="pull-right">'
		Account.current.all_language_objects.each do |language|
			content << language_icon(solution_meta, language)
		end
		content << '</span>'
		content << '</div>'
		content.html_safe
	end

	def language_icon(solution_meta, language)
		category = solution_meta.class.short_name
		return version_view_icon(solution_meta, language) unless edit_privilege?(category)
		options = {
			:class => "language_icon #{language_style(solution_meta, language)} custom-tip-top",
			:title => language_label_title(language, solution_meta.safe_send("#{language.to_key}_available?")),
			:id => "version-#{solution_meta.id}-#{language.id}",
			:"data-tip-classes" => 'ui-tooltip-dark',
		}
		options.merge!({:rel => "freshdialog",
			:data => {
			"modal-title" => "#{t("solution.edit_#{category}")}#{language_label(language)}",
			"target" => "#version-#{solution_meta.id}-l#{language.id}",
			"close-label" => t('cancel'),
			"submit-label" => t('save')
		}}) unless category.eql?('article')
		options.merge!({:"data-pjax" => "#body-container"}) if category.eql?('article')
		link_to( "<span class='language_name'>#{language.short_code.capitalize}</span>
							#{ font_icon( (solution_meta.safe_send("#{language.to_key}_available?") ? 'pencil' : 'plus'), :size => 14) }".html_safe,
							category.eql?('article') ?
							solution_article_version_path(solution_meta.id, language.code, :anchor => 'edit') :
							safe_send("edit_solution_#{category}_path", solution_meta, :language_id => language.id),
							options)
	end

	def version_view_icon(solution_meta, language)
		category = solution_meta.class.short_name
		options = {
			:class => "language_symbol #{language_style(solution_meta, language)} tooltip",
			:title => language.name,
			:id => "version-#{solution_meta.id}-#{language.id}",
		}
		if category.eql?('article')
			options.merge!({:"data-pjax" => "#body-container"})
			link_to("<span class='language_name'>#{language.short_code.capitalize}</span>".html_safe,
								solution_article_version_path(solution_meta.id, language.code),
								options)
		else
			content_tag(:span, "<span class='language_name'>#{language.short_code.capitalize}</span>".html_safe, options)
		end
	end

	def edit_privilege?(category)
		@edit_privilege ||= begin
			case category.to_sym
			when :category, :folder
				privilege?(:manage_solutions)
			when :article
				privilege?(:publish_solution)
			end
		end
	end

	def language_label_title language, flag
		if language.code == Account.current.language
			t("solution.language_label_titles.primary_edit", :name => language.name)
		else
			flag ? t("solution.language_label_titles.supporting_edit", :name => language) : t("solution.language_label_titles.supporting_new", :name => language)
		end
	end

	def language_style(meta_obj, language)
		return 'normal' unless meta_obj
    classes = []
    classes << 'unavailable' unless meta_obj.safe_send("#{language.to_key}_available?")
    if meta_obj.is_a? Solution::ArticleMeta
      classes << 'unpublished' unless meta_obj.safe_send("#{language.to_key}_published?")
      classes << 'outdated' if Account.current.language_object != language && meta_obj.safe_send("#{language.to_key}_outdated?")
      classes << 'draft' if meta_obj.safe_send("#{language.to_key}_draft_present?")
    end
    classes.join(' ')
  end

  def language_label(l = current_account.language_object)
  	return "" unless current_account.multilingual?
  	content_tag(:span, l.name, :class => 'label pull-right')
  end

	def primary_preview(primary, identifier, current_obj = nil)
		return unless primary.present? && primary != current_obj
		"<b class='muted'>#{Language.for_current_account.name}:</b>
		<span class='muted'>#{h(primary.safe_send(identifier))}<span>".html_safe unless primary.safe_send(identifier).blank?
	end

	def dynamic_text_box(f, language, form, options = {})
		op = ""
		parent_meta = instance_variable_get("@#{f}_meta")
		if parent_meta && !options[:primary] && parent_meta.safe_send("#{language.to_key}_available?")
			op << "<div class='pt5 span12'>"
			op << h(parent_meta.safe_send("#{language.to_key}_#{f}").name)
			op << "</div>"
		else

			op << text_field_tag("#{form.object_name}[#{language.to_key}_#{f}][name]", nil,
	                         :class => "required #{options[:class]}",
	                         :id => "#{options[:id]}",
	                         :autocomplete => "off",
	                         :autofocus => true,
	                         :disabled => options[:disabled] || false,
	                         :placeholder => title_placeholder(f.to_s.pluralize))
			if parent_meta && !options[:primary]
		    op << hidden_field_tag("#{form.object_name}[id]", parent_meta.id)
		    op << primary_preview(parent_meta.safe_send("primary_#{f}"), :name)
			end
	  end
    op.html_safe
	end

	def new_article_btn article
	  output = %(<div class="btn-group">)
	  output << pjax_link_to(article[0],article[1],
	  	                     article[3].merge({:class => "btn btn-primary"}))
	  output << %(</div>)
	  output.html_safe
	end

	def draft_label_popover article_meta
		op = ""
		options = {:class => "label"}
		label = "<span class='draft-label'>#{t('solutions.status.draft')}</span>"
		return content_tag(:span, label.html_safe, options).html_safe unless current_account.multilingual?
		options.merge!({ :rel => "draft-qtip",
			"data-content-id" => "languages-qtip-contents-#{article_meta.id}"})
		op << content_tag(:a, label.html_safe, options)
		op << "<div id='languages-qtip-contents-#{article_meta.id}' class='hide'>"
		op << languages_popover(article_meta)
		op << "</div>"
		op.html_safe
	end

	def languages_popover article_meta
		op = ""
		draft_languages = Account.current.all_language_objects.select { |l| article_meta.safe_send("#{l.to_key}_draft_present?") }
		draft_languages.first(5).each do |language|
			op << "<div class='language_item'>"
			op << "<span class='language_symbol #{language_style(article_meta, language)}'>"
			op << "<span class='language_name'>#{language.short_code.capitalize}</span>"
			op << "</span>"
			op << "<span class='language_label'> #{language.name}</span>"
			op << "</div>"
		end
		op << "<div class='language_item text-center'>+#{t('solution.articles.more_languages', :count => draft_languages.size - 5)}</div>" if draft_languages.size > 5
		op
	end

	def category_delete_btn category
		confirm_delete(category, solution_category_path(category))
	end

	def folder_delete_btn folder
		confirm_delete(folder, solution_folder_path(folder))
	end

	def solution_modal_footer object
		output = %(<div class="modal-footer">)
		output << %(<div class="pull-left">)
		if object.is_a?(Solution::FolderMeta)
			output << folder_delete_btn(object)
		else
			output << category_delete_btn(object)
		end
		output << %(</div></div>)
		output.html_safe
	end

	def solution_body_classes
		"community solutions #{'multilingual' if current_account.multilingual?}"
	end

	def category_create_new(f)
		op = ""
		op << link_to(t('solution.create_new'), '', :id => 'create-new-category', :class => 'inline-block ml15 mt7')
		op << %(<div class='inline-block mb4'>)
		f.fields_for(:solution_category_meta) do |category_fields|
      op << text_field_tag("solution_folder_meta[solution_category_meta][primary_category][name]", nil,
	                         :class => "required hide input-large",
	                         :id => "create-category-text",
	                         :autocomplete => "off",
                           :disabled => true,
	                         :placeholder => title_placeholder('categories'))
		end
		op << %(</div>)
		op << %(<div class='inline-block'>)
		op << link_to(t('cancel'), '', :id => 'cancel-create-new', :class => 'ml15 hide')
		op << %(</div>)
		op.html_safe
	end

	def folder_create_new
		op = t('solution.folder')
		if privilege?(:manage_solutions)
			op << "<span id='create-new'> - "
			op << link_to(t('solution.create_new'), new_solution_folder_path((btn_default_params(:folder) || {}).merge({ :article => true })), new_btn_opts(:folder))
			op << "</span>"
		end
		op.html_safe
	end

	def path_url_locale
		current_account.multilingual? ? { :url_locale => @language.code } : {}
	end

	def article_history article
		modified_flag = article.published? && article.modified_at.present? && (article.created_at != article.modified_at)
		time = modified_flag ? article.modified_at : article.created_at
		op = modified_flag ? t('solution.general.last_published') : t('solution.general.created_by')
		op << " #{modified_flag && article.modified_by.present? ? h(article.recent_author.name) : h(article.user.name)}, "
		op << "<abbr data-livestamp=#{time.to_i}>#{formated_date(time)}</abbr>"
		op.html_safe
	end

  def full_error(attr, msg)
    [t("activerecord.attributes.#{attr}", :default => "#{attr.to_s.gsub('.', '_').humanize}"),
      msg].join(' ')
  end

  def article_title(meta)
  	(meta.primary_article.draft || meta.primary_article).title
  end

  def article_tooltip_title(meta)
  	title = article_title(meta)
  	title.length > 75 ? title : ''
	end

	def title_placeholder(item_type)
		Account.current.multilingual? ?
			t("solution.#{item_type}.enter_version_name", :language_name => @language.name) : ''
	end

	def grouped_options_for_folder_select
		all_solution_categories.map { |category|
			[category[:name], category[:folders].map { |folder| [folder[:name], folder[:id]] }]
		}
	end

	def all_solution_categories_with_bot
		current_account.solution_category_meta.preload({:portals => :bot}).where(:is_default => false).map do |c| 
			{
				:id => c.id, 
				:bot => c.portals.select{ |portal| portal.bot.present? }.present?
			}
		end
	end

    def update_suggested(articles_suggested)
      return if articles_suggested.blank?

      articles_hash = modify_articles_suggested_hash(articles_suggested)
      articles_hash.each do |article_id, language_ids|
        articles_data = Account.current.solution_articles.where(parent_id: article_id, language_id: language_ids)
        articles_data.each(&:suggested!) if articles_data
      end
    end

    def cumulative_attachment_limit
      Account.current.kb_increased_file_limit_enabled? && Account.current.account_additional_settings.additional_settings.key?(:kb_cumulative_attachment_limit) ? Account.current.account_additional_settings.additional_settings[:kb_cumulative_attachment_limit] : Account.current.attachment_limit
    end

    def valid_attachments(article, draft, type = :attachments)
      article_attachments = article.safe_send(type)
      active_attachments = draft.present? ? remove_deleted_attachments(article_attachments + draft.safe_send(type), draft.meta, type) : article_attachments
      active_attachments
    end

    def base64_content?(content)
      return false if Account.current.kb_allow_base64_images_enabled?

      content ? content.match(/src\s*=\s*("|')data:((image\/(png|gif|jpg|jpeg|svg\+xml){1})|(text\/(plain|html){1})){1};base64/i) : false
    end

    def allow_chat_platform_attributes?
      Account.current.omni_bundle_account? && Account.current.launched?(:kbase_omni_bundle)
    end

    def any_platforms_enabled?(meta, platform_hash)
      new_platform_values = meta.solution_platform_mapping.modified_new_platform_values(platform_hash)
      SolutionPlatformMapping.any_platform_enabled?(new_platform_values)
    end

    private

      def modify_articles_suggested_hash(articles_suggested)
        articles_hash = {}
        articles_suggested.each do |article|
          language_id = Language.find_by_code(article[:language]).id
          article_id = article[:article_id]

          articles_hash[article_id] = articles_hash.key?(article_id) ? articles_hash[article_id] : []
          articles_hash[article_id].push(language_id) unless articles_hash[article_id].include?(language_id)
        end

        articles_hash
      end

      def remove_deleted_attachments(attachments, draft_meta, type = :attachments)
        if draft_meta.present? && draft_meta[:deleted_attachments].present? && draft_meta[:deleted_attachments][type].present?
          deleted_att_ids = draft_meta[:deleted_attachments][type]
          attachments = attachments.reject { |a| deleted_att_ids.include?(a.id) }
        end
        attachments
      end
end
