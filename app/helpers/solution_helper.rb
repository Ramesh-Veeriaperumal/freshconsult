module SolutionHelper

	def solutions_breadcrumb(page = :home)
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
		category = [t('article.add_category'), new_solution_category_path]
		folder    = [t('article.add_folder'),    new_solution_folder_path(btn_default_params(:folder))]
		article    = [t("article.add_article"),    new_solution_article_path(btn_default_params(:article))]
		opts     = {:"data-pjax" => "#body-container"}

		if privilege?(:manage_solutions)
			article = nil unless privilege?(:publish_solution)
			case default_btn
				when :category
					btn_dropdown_menu(category, [folder, article], opts)
				when :folder
					btn_dropdown_menu(folder, [category, article], opts)
				else
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

	def btn_default_params(type)
		case type
			when :folder
				{ :category_id => @category.id } if @category.present?
			when :article
				{ :folder_id => @folder.id } if @folder.present?
		end
	end

	def sidebar_toggle(extra_classes="")
		font_icon("sidebar-list",
								:size => 21,
								:class => "cm-sb-toggle #{extra_classes}",
								:id => "cm-sb-toggle").html_safe
	end

	def reorder_btn
		_op = ""
		_op << %(<a href="#" class="btn" id="reorder_btn">
	             #{font_icon "reorder", :size => 13}
	             #{t('reorder')}
					   </a>) if privilege?(:manage_solutions)
		_op.html_safe
	end
end