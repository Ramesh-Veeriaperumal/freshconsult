module Solution::NavmenuHelper
  
  def navmenu_categories
    [category_list(current_categories), category_list(other_categories)].join('').html_safe
  end
  
  def category_list(categories)
    op = []
    categories.each do |category|
      next if category[:is_default]
      op << %(<li class="cm-sb-cat-item">)
      op << %(<i class="forum_expand"></i>) unless category[:folders].blank?
      op << pjax_link_to(category[:name].truncate(35), solution_category_path(:id => category[:id]), {
                  :"data-category-id" => category[:id],
                  :id => "sb-solutions-category-#{category[:id]}"
                })
      op << folder_list(category[:folders], category[:id])
      op << %(</li>)
    end
    op
  end
  
  def folder_list(folders, category_id)
    op = []
    op << %( <ul class="forum_list" id="#{category_id}_folders"> )
    folders.each do |folder|
      next if folder[:is_default]
      op << %( <li class="forum_list_item" id="#{folder[:id]}_folder"> )
      op << pjax_link_to( "#{h(folder[:name].truncate(30))} (#{folder[:article_count]})&lrm;".html_safe,
                          solution_folder_path(:id => folder[:id]), {
                            :"data-folder-id" => folder[:id],
                            :"data-category-id" => category_id,
                            :id => "sb-solutions-folder-#{folder[:id]}"
                        })
      op << %( </li> )
    end
    op << %( </ul> )
    op.join('').html_safe
  end
  
  def cache_key
    MemcacheKeys::SOLUTION_NAVMENU % {
      :account_id => current_account.id,
      :portal_id => current_portal.id
    }
  end
end