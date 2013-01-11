module LimitExceedRescue

  def self.included(base) 
  	base.extend ClassMethods
		base.rescue_from HelpdeskExceptions::AttachmentLimitException do |exception|
			Rails.logger.error("Error while adding item attachments::: LIMIT EXCEED ")
	    respond_to do |format|
	      format.html {
	        flash[:notice] = t('helpdesk.tickets.note.attachment_size.exceed')
	        redirect_to :back
	      }
	      format.xml do 
	        result = {:error=>t('helpdesk.tickets.note.attachment_size.exceed')}
	        render :xml =>result.to_xml(:indent =>2,:root=> :errors), :status =>:not_found
	      end
	      format.json do 
	        render :json => {:errors =>{:error =>t('helpdesk.tickets.note.attachment_size.exceed')} }.to_json, 
	        :status => :not_found
	      end
	    end
		end
  end
end