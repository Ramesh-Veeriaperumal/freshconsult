module SolutionHelper
	include Solution::Cache
	
	def solutions_breadcrumb(page = :home)
		return if page == :home
		_output = []
		_output << pjax_link_to(t('solution.title'), solution_categories_path)
		if default_category?
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
				t('solutions.search_in', :search_scope => @category.name)
			when :folder
				t('solutions.search_in', :search_scope => @folder.name)
			else
				t('solutions.search_all')
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
				{ :folder_id => @folder.id } if @folder.present?
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
	
end
