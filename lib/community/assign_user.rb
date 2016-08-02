module Community::AssignUser

  def assign_user 
    @creating_user ||= begin
      user = nil
      if privilege?(:admin_tasks)
        unless (params[controller_name.singularize.to_sym][:import_id].blank? && params[:email].blank?)
          user = current_account.all_users.where(email: params[:email]).first
        end
        unless  params[controller_name.singularize.to_sym][:user_id].blank?
          user = current_account.all_users.where(:id => params[controller_name.singularize.to_sym][:user_id]).first
        end
      end
      user || current_user
    end
  end
  
end