module FalconHelperMethods
  def falcon_redirect_check(root_path)
    if falcon_enabled?
      "parent.location.href='#{root_path}'"
    else
      "window.location.href='#{root_path}'"
    end
    end

  def falcon_enabled?
    current_account && current_account.launched?(:falcon) && current_user && current_user.is_falcon_pref?
end
end



