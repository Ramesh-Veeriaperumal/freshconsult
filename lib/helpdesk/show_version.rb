module Helpdesk::ShowVersion

  def set_show_version
    if cookies[:new_details_view].present?
      cookies.delete(:new_details_view) 
    end
    @new_show_page = true
  end

end