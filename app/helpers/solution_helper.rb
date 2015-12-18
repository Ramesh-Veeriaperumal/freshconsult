module SolutionHelper
	include Solution::Cache
	
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
					_output << truncate(h(@category.name), :length => 120)
				when :folder
					_output << category_link(@folder, page)
					_output << truncate(h(@folder.name), :length => 50)
				when :article
					_output << category_link(@article_meta.solution_folder_meta, page)
					_output << folder_link(@article_meta.solution_folder_meta)
				else
			end
		end
		"<div class='breadcrumb'>#{_output.map{ |bc| "<li>#{bc}</li>" }.join("")}</div>".html_safe
	end

	def new_article_check?
		@article_meta.present? && @article_meta.new_record?
	end

	def search_placeholder(page)
		case page
			when :category
				t('solution.articles.search_in', :search_scope => @category.name)
			when :folder
				t('solution.articles.search_in', :search_scope => @folder.name)
			else
				t('solution.articles.search_all')
		end
	end

	def default_category?
		((@category || (@folder.respond_to?(:solution_category_meta) ? @folder.solution_category_meta : (@article.folder.present? ? @article.folder.category : {}))) || {})[:is_default]
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
					opts = { "data-modal-title" => t("solution.add_category"), "data-target" => "#new-cat" }
					btn_dropdown_menu(category, [folder, article], opts.merge(default_new_btn_opts))
				when :folder
					opts = { "data-modal-title" => t("solution.add_folder"), "data-target" => "#new-fold" }
					btn_dropdown_menu(folder, [category, article], opts.merge(default_new_btn_opts))
				else
					opts = { :"data-pjax" => "#body-container" }
					if privilege?(:publish_solution)
						btn_dropdown_menu(article, [category, folder], opts)
					else
						btn_dropdown_menu(folder, [category], opts)
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
			default_new_btn_opts.merge({ "data-modal-title" => t("solution.add_category"), "data-target" => "#new-cat" })
		when :folder
			default_new_btn_opts.merge({ "data-modal-title" => t("solution.add_folder"), "data-target" => "#new-fold" })
		when :article
			{ :"data-pjax" => "#body-container", :rel => nil }
		end
	end

	def btn_default_params(type)
		case type
			when :category
				{:portal_id => params[:portal_id]} if params[:portal_id].present?
			when :folder
				{ :category_id => @category.id } if @category.present?
			when :article
				@folder.present? ? ({ :folder_id => @folder.id }) : (@category.present? ? { :category_id => @category.id } : nil)
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
					   </a>) if privilege?(:manage_solutions)
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
					class="orphan-cat-info">
				#{t('solution.orphan_category_info')}</span>
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
    drafts.for_sidebar.first(3).each do |draft|
      content << sidebar_drafts(draft)
    end
    content << %{</ul>}
    content << pjax_link_to( t('solution.sidebar.view_all'),
    												drafts_path(container_id), { :class => "view-all"}) if drafts.size > 3
		content << %{</div>}
		content.html_safe
	end

	def drafts_path container_id
		container_id == 'drafts-all' ? solution_my_drafts_path('all') : solution_drafts_path
	end
	
	def multilingual_article_path(article, options={})
		current_account.multilingual? ?
			solution_article_version_path(article, options.slice(:anchor).merge({:language => article.language.to_key})) :
			solution_article_path(article, options.slice(:anchor))
	end

	def sidebar_feedbacks_list(feedbacks, container_id, active='')
		filter = (container_id == 'feedbacks-me') ? 'my_article_feedback' : 'article_feedback'
		content = %{<div class='tab-pane sidebar-list #{active}' id="#{container_id}"><ul>}
    feedbacks.to_a.first(3).each do |feedback|
      content << article_feedback(feedback)
    end
    content << %{</ul>}
    content << pjax_link_to( t('solution.sidebar.view_all'),
    												 "/helpdesk/tickets/filter/#{filter}",
    												  { 
    												  	:class => "view-all",
    												  	:"data-parallel-url" => "/helpdesk/tickets/filter_options?filter_name=#{filter}",
    												  	:"data-parallel-placeholder" => "#ticket-leftFilter"
    												  }) if feedbacks.size > 3

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

	def language_flags(solution_meta)
		content = ""
		([Account.current.language_object] + Account.current.supported_languages_objects).each do |language|
			content << language_icon(solution_meta, language)
		end
		content.html_safe
	end

	def language_icon(solution_meta, language)
		category = solution_meta.class.short_name
		availability_flag = solution_meta.send("#{language.to_key}_available?")
		options = { 
			:class => "language_icon #{language_style(solution_meta, language)} tooltip",
			:title => language_label_title(language, availability_flag),
			:id => "version-#{solution_meta.id}-#{language.id}",
		}
		options.merge!({:rel => "freshdialog",
			:data => {
			"modal-title" => "#{t("solution.edit_#{category}")}<span class='label pull-right'>#{language.name}</span>",
			"target" => "#version-#{solution_meta.id}-l#{language.id}",
			"close-label" => t('cancel'),
			"submit-label" => t('save')
		}}) unless category.eql?('article')
		options.merge!({:"data-pjax" => "#body-container"}) if category.eql?('article')
		link_to( "<span class='language_name'>#{language.short_code.capitalize}</span>
							<span class='ficon-pencil fsize-14'></span>".html_safe, 
							category.eql?('article') ? 
							availability_flag ? solution_article_version_path(solution_meta.id, language.code) :
							solution_new_article_version_path(solution_meta.id, language.code) :
							send("edit_solution_#{category}_path", solution_meta, :language_id => language.id),
							options)
	end

	def language_label_title language, flag
		if language.code == Account.current.language
			t("solution.language_label_titles.primary_edit", :name => language.name)
		else
			flag ? t("solution.language_label_titles.supporting_edit", :name => language) : t("solution.language_label_titles.supporting_new", :name => language)
		end
	end

	def language_style(meta_obj, language)
    classes = []
    classes << 'unavailable' unless meta_obj.send("#{language.to_key}_available?")
    if meta_obj.is_a? Solution::ArticleMeta
      classes << 'unpublished' unless meta_obj.send("#{language.to_key}_published?")
      classes << 'outdated' if Account.current.language_object != language && meta_obj.send("#{language.to_key}_outdated?")
      classes << 'draft' if meta_obj.send("#{language.to_key}_draft_present?")
    end
    classes.join(' ')
  end

	def primary_preview(primary, identifier, current_obj = nil)
		return unless primary.present? && primary != current_obj
		"<b>#{Language.for_current_account.name}:</b>
		<span class='muted'>#{primary.send(identifier)}<span>".html_safe unless primary.send(identifier).blank?
	end

	def dynamic_text_box(f, language, form)
		op = ""
		parent_meta = instance_variable_get("@#{f}_meta")
		obj_version = parent_meta.send("#{language.to_key}_#{f}")
		if obj_version.present?
			op << "<div class='pt5'>"
			op << obj_version.name
			op << "</div>"
		else
			op << text_field_tag("#{form.object_name}[#{language.to_key}_#{f}][name]", nil,
	                         :class => "required",
	                         :autocomplete => "off",
	                         :autofocus => true)
	    op << hidden_field_tag("#{form.object_name}[id]", parent_meta.id)
	    op << primary_preview(parent_meta.send("primary_#{f}"), :name)
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

	def languages_popover article_meta
		op = ""
		Account.current.all_language_objects.select { |l| article_meta.send("#{l.to_key}_draft_present?") }.each do |language|
			op << "<div class='language_item'>"
			op << "<span class='language_symbol #{language_style(article_meta, language)}'>"
			op << "<span class='language_name'>#{language.short_code.capitalize}</span>"
			op << "</span>"
			op << "<span class='language_label'>#{language.name}</span>"
			op << "</div>"
		end
		op.html_safe
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
end
