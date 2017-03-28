module Settings::Pipe
  class HelpdeskController < ::Settings::HelpdeskController

    def toggle_email
        validate_params
        if params[:disabled] == true
            Account.current.launch(:disable_emails)
        else
            Account.current.rollback(:disable_emails)
        end 
      @item = {disabled: Account.current.launched?(:disable_emails)}
      
    end 

    private 
        def validate_params
            field = "disabled"
            params[cname].permit(*field)
            toggle = Pipe::HelpdeskValidation.new(params)
            render_custom_errors(toggle, true) unless toggle.valid?
        end
  end
end