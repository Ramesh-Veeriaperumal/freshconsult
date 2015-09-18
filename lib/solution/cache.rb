module Solution::Cache
  def category_collection(portal = current_portal)
    @category_collection ||= begin
      if portal.blank?
        {:current => all_categories, :others => []}
      else
        {
          :current => all_categories.select {|c,v| visible_in_current_portal?(c[:portal_solution_categories],portal.id) },
          :others => all_categories.reject {|c,v| visible_in_current_portal?(c[:portal_solution_categories],portal.id) }
        }
      end
    end
  end
  
  def all_categories
    @all_categories_from_cache ||= current_account.solution_categories_from_cache
  end
  
  def current_categories
    @current_categories_from_cache ||= begin
      category_collection[:current].sort do |x,y|
        category_sort_order(x) <=> category_sort_order(y)
      end
    end
  end
  
  def other_categories
    @other_categories_from_cache ||= begin
      category_collection[:others].sort do |x,y|
        x[:position] <=> y[:position]
      end
    end
  end
    
  def category_sort_order(cat)
    (cat[:portal_solution_categories].select do |psc|
      psc[:portal_id] == current_portal.id
    end).first[:position].to_i
  end

  def visible_in_current_portal?(portal_sol_cat,portal_id)
    p_ids = []
    portal_sol_cat.each { |psc| p_ids << psc[:portal_id] }
    p_ids.include?(portal_id)
  end
end
