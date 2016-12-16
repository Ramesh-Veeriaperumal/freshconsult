module Helpdesk::CustomFields::CustomFieldMethods

  def invoke_respond_to err_str, data
    respond_to do |format|
      format.html {
        yield
      }
      format.json {
        if err_str.present?
          render :json => {success: false, errors: err_str}
        else
          render :json => {success: true, data: data}
        end
      }
    end
  end

end