module FalconHelperMethods
  def falcon_redirect_check(root_path)
    if current_account && current_account.falcon_ui_enabled?(current_user)
      "parent.location.href='#{root_path}'"
    else
      "window.location.href='#{root_path}'"
    end
  end

end
