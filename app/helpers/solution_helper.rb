module SolutionHelper
	include Solution::Cache
	
	def solutions_breadcrumb(page = :home)
		return if page == :home
		_output = []
		_output << pjax_link_to(t('solution.title'), solution_categories_path)
		if page != :all_category && default_category?
			if @article.present? && @article.new_record?
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
					_output << category_link(@article.folder, page)
					_output << folder_link(@article.folder)
				else
			end
		end
		"<div class='breadcrumb'>#{_output.map{ |bc| "<li>#{bc}</li>" }.join("")}</div>".html_safe
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
		((@category || (@folder.respond_to?(:category) ? @folder.category : @article.folder.category)) || {})[:is_default]
	end

	def folder_link folder
		options = { :title => folder.name } if folder.name.length > 40
		pjax_link_to(truncate(folder.name, :length => 40), solution_folder_path(folder.id), (options || {}))
	end

	def category_link(folder, page)
		truncate_length = ( (page == :folder) ? 70 : 40 )
		category_name = folder.category.name
		options = { :title => category_name } if category_name.length > truncate_length
		pjax_link_to(truncate(folder.category.name, :length => truncate_length), 
			 			"/solution/categories/#{folder.category_id}", (options || {}))
	end
	
	def new_solutions_button(default_btn = :article)
		category = [t('solution.add_category'), new_solution_category_path, false, new_btn_opts(:category)]
		folder    = [t('solution.add_folder'),    new_solution_folder_path(btn_default_params(:folder)), false, new_btn_opts(:folder)]
		article    = [t("solution.add_article"),    new_solution_article_path(btn_default_params(:article)), false, new_btn_opts(:article)]

		if privilege?(:manage_solutions)
			article = nil unless privilege?(:publish_solution)
			case default_btn
				when :category
					opts = { :title => t("solution.add_category"), "data-target" => "#new-cat" }
					btn_dropdown_menu(category, [folder, article], opts.merge(default_new_btn_opts))
				when :folder
					opts = { :title => t("solution.add_folder"), "data-target" => "#new-fold" }
					btn_dropdown_menu(folder, [category, article], opts.merge(default_new_btn_opts))
				else
					opts = { :"data-pjax" => "#body-container" }
					if privilege?(:publish_solution)
						btn_dropdown_menu(article, [category, folder], opts)
					else
						btn_dropdown_menu(folder, [category], opts)
					end
			end
		elsif privilege?(:create_article)
			pjax_link_to(*article, :class => 'btn')
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
			default_new_btn_opts.merge({ :title => t("solution.add_category"), "data-target" => "#new-cat" })
		when :folder
			default_new_btn_opts.merge({ :title => t("solution.add_folder"), "data-target" => "#new-fold" })
		when :article
			{ :"data-pjax" => "#body-container", :title => nil, :rel => nil }
		end
	end

	def btn_default_params(type)
		case type
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
                        :time => f.created_at,
                        :time_string => time_ago_in_words(f.created_at)).html_safe, helpdesk_ticket_path(f))}
	        <span class="feedback-article">
	          #{t('solution.on')}
	          <span title="#{ f.article.title if f.article.title.length > 22 }">#{ f.article.title.truncate(25) }</span>
	        </span>
	        <div class="muted">#{ t('solution.sidebar.feedbacks.status', :status => f.status_name) }</div>
	      </div>
      </li>}.html_safe
	end

	def sidebar_drafts a
		%{
			<li>
        <div class="sidebar-list-item">
          #{pjax_link_to(a.title.truncate(27),
                          solution_article_path(a.article_id)
                         )}
	        <div class="muted"> 
	          #{t('solution.sidebar.drafts.details',
	                            :name => a.user.name, 
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


	def sidebar_feedbacks_list(feedbacks, container_id, active='')
		content = %{<div class='tab-pane sidebar-list #{active}' id="#{container_id}"><ul>}
    feedbacks.first(3).each do |feedback|
      content << article_feedback(feedback)
    end
    content << %{</ul>}
    content << pjax_link_to( t('solution.sidebar.view_all'),
    												 "/helpdesk/tickets/filter/article_feedback",
    												  { :class => "view-all"}) if feedbacks.size > 3
		content << %{</div>}
		content.html_safe
	end

	def option_selector_name identifier
		identifier.delete(' ').underscore 
	end

	def language_flags(solution_meta)
		content = ""
		category = solution_meta.class.name.chomp('Meta').gsub("Solution::", '').downcase
		Account.current.supported_languages.each do |lan|
			language = Language.find_by_code(lan)
			version = solution_meta.send("#{lan.gsub('-','_').downcase}_#{category}")
			case category.to_sym
				when :category
					content << language_icon_category(solution_meta, version, language)
				when :folder
				when :article
				else
			end
		end
		content.html_safe
	end

	def language_icon_category(solution_meta, version, language)
		link_to( "<span class='language_name'>#{language.name[0..1].capitalize}</span>".html_safe, 
			edit_solution_category_path(solution_meta, :language_id => language.id),
			:rel => "freshdialog",
			:class => "language_icon #{'active' if version.present?} tooltip",
			:title => language.name,
			:id => "version-#{solution_meta.id}-#{language.id}",
			:data => {
				"destroy-on-close" => true,
				"modal-title" => "#{t('solutions.edit')}<span class='label pull-right'>#{language.name}</span>",
				"target" => "#version-#{solution_meta.id}",
				"close-label" => t('cancel'),
				"submit-label" => t('save')
			})
	end
end
