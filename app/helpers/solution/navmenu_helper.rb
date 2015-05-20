module Solution::NavmenuHelper
  
  def navmenu_categories
    op = []
    cportal.solution_categories.all(:include => :folders).each do |category|
      next if category.is_default?
      op << %(<li class="cm-sb-cat-item">)
      op << %(<i class="forum_expand"></i>) unless category.folders.blank?
      op << pjax_link_to(category.name, solution_category_path(category), {
                  :"data-category-id" => category.id,
                  :id => "sb-#{dom_id(category)}"
                })
      op << folder_list(category.folders, category.id)
      op << %(</li>)
    end
    op.join('').html_safe
  end
  
  def folder_list(folders, category_id)
    op = []
    op << %( <ul class="forum_list" id="#{category_id}_folders"> )
    folders.each do |folder|
      next if folder.is_default?
      op << %( <li class="forum_list_item" id="#{folder.id}_folder"> )
      op << pjax_link_to( "#{folder.name} (#{folder.articles.size})",
                          solution_folder_path(folder), {
                            :"data-folder-id" => folder.id,
                            :"data-category-id" => category_id,
                            :id => "sb-#{dom_id(folder)}"
                        })
      op << %( </li> )
    end
    op << %( </ul> )
    op.join('').html_safe
  end
  
  def cportal
    Portal.find(1)
  end
  
  def cache_key
    MemcacheKeys::SOLUTION_NAVMENU % {
      :account_id => current_account.id,
      :portal_id => cportal.id
    }
  end
end