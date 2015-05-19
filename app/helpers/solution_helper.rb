module SolutionHelper
	def new_solutions_button(default_btn = :article)
	  category = [t('topic.add_category'), new_solution_category_path]
	  # folder = [t('solution.folders.new.new_folder'), new_solution_category_folder_path(btn_default_params(:folder))]
	  # article = [t("solution.add"),    new_solution_category_folder_article_path(btn_default_params(:article))]
	  opts = {:"data-pjax" => "#body-container"}

	  if privilege?(:manage_solutions)
	    # article = nil unless privilege?(:publish_solution)
	    case default_btn
	      when :category
	        btn_dropdown_menu(category, opts)
	      when :folder
	        btn_dropdown_menu(folder, [category, article], opts)
	      else
	        if privilege?(:publish_solution)
	        	btn_dropdown_menu(solution, [category, folder], opts)
	        else
	        	btn_dropdown_menu(folder, [category], opts)
	        end
	    end
		else
			""
	  end
	end

	def btn_default_params(type)
	  case type
	    when :folder
	      { :folder_category_id => @category.id } if @category.present?
	    when :article
	      { :folder_id => @folder.id } if @folder.present?
	    else
	  end
	end

	def sidebar_toggle(extra_classes="")
		font_icon("sidebar-list",
								:size => 21,
								:class => "cm-sb-toggle #{extra_classes}",
								:id => "cm-sb-toggle").html_safe
	end
end