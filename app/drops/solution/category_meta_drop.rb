class Solution::CategoryMetaDrop < Solution::CategoryDrop

  def folders_count
    @folders_count ||= @source.solution_folder_meta.visible(portal_user).size
  end

  def folders
    @folders ||= @source.solution_folder_meta.visible(portal_user)
  end

end
