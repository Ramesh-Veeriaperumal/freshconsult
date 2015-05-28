module SolutionHelper

	def solutions_breadcrumb(page = :home)
		return if page == :home
		_output = []
		_output << pjax_link_to(t('solution.title'), solution_categories_path)
		case page
			when :category
				_output << truncate(h(@category.name), :length => 120)
			when :folder
				_output << category_link(@folder, page)
				_output << truncate(h(@folder.name), :length => 50)
			when :article
				_output << category_link(@folder, page)
				_output << folder_link(@folder)
			else
		end
		"<div class='breadcrumb'>#{_output.map{ |bc| "<li>#{bc}</li>" }.join("")}</div>".html_safe
	end

	def folder_link folder
		options = { :title => folder.name } if folder.name.length > 40
		pjax_link_to(truncate(folder.name, :length => 40), solution_folder_path(folder.category.id, folder.id), (options || {}))
	end

	def category_link(folder, page)
		truncate_length = ( (page == :folder) ? 70 : 40 )
		category_name = folder.category.name
		options = { :title => category_name } if category_name.length > truncate_length
		pjax_link_to(truncate(folder.category.name, :length => truncate_length), 
			 			"/solution/categories/#{folder.category_id}", (options || {}))
	end
	
	def new_solutions_button(default_btn = :article)
		category = [t('article.add_category'), new_solution_category_path, false, new_btn_opts(:category)]
		folder    = [t('article.add_folder'),    new_solution_folder_path(btn_default_params(:folder)), false, new_btn_opts(:folder)]
		article    = [t("article.add_article"),    new_solution_article_path(btn_default_params(:article)), false, new_btn_opts(:article)]

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
					if privilege?(:publish_solution)
						btn_dropdown_menu(article, [category, folder])
					else
						btn_dropdown_menu(folder, [category])
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
			"data-submit-label" => t('save')
		}
	end

	def new_btn_opts(type)
		case type
		when :category
			default_new_btn_opts.merge({ :title => t("solution.add_category"), "data-target" => "#new-cat" })
		when :folder
			default_new_btn_opts.merge({ :title => t("solution.add_folder"), "data-target" => "#new-fold" })
		when :article
			default_new_btn_opts.merge({ :"data-pjax" => "#body-container" })
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
	
	def category_collection(portal = current_portal)
		@category_collection ||= begin
			if portal.blank?
				{:current => all_categories, :others => []}
			else
				{
					:current => all_categories.select {|c| c.portal_solution_categories.map(&:portal_id).include?(portal.id) },
					:others => all_categories.reject {|c| c.portal_solution_categories.map(&:portal_id).include?(portal.id) }
				}
			end
		end
	end
	
	def all_categories
		@all_categories_from_cache ||= current_account.solution_categories_from_cache
	end
	
	def current_categories
		category_collection[:current].sort do |x,y|
			category_sort_order(x) <=> category_sort_order(y)
		end
	end
	
	def other_categories
		category_collection[:others].sort do |x,y|
			x.position <=> y.position
		end
	end
	
	def category_sort_order(cat)
		(cat.portal_solution_categories.select do |psc|
			psc.portal_id == current_portal.id
		end).first.position
	end

	def helpcard_content(notes, title, info_base)
		output = []
		output << %(<h3 class="lead">#{t(title).html_safe}</h3>)
		notes.each do |num|
			output << %(<p> #{t(info_base + num.to_s).html_safe} </p>)
		end
		output.join("").html_safe
	end
	
end
