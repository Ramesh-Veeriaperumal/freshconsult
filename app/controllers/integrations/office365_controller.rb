class Integrations::Office365Controller < Admin::AdminController
  include Integrations::Office365::AuthHelper

  skip_before_filter :check_privilege, :verify_authenticity_token
  before_filter :verify_request

  def note
    begin
      note_body = params["note"]
      create_note(@ticket, note_body, User.current)
      response.headers["CARD-ACTION-STATUS"] = "The note has been created."
      render :json => 200 and return
    rescue Exception => e
      Rails.logger.error "Office 365 :: note creation failed. {:account => #{current_account}, :ticket => #{@ticket.id} :: \n #{e} \n #{e.backtrace}"
      NewRelic::Agent.notice_error(e,{:custom_params => {:account_id => current_account.id, :description => "Unable to create a note. : #{e.message}"}})
    end 
    response.headers["CARD-ACTION-STATUS"] = "Note could not be created."
    render :json => 404 and return
  end

  def status
    begin
      @ticket.status = params["status"]
      @ticket.save!
      response.headers["CARD-ACTION-STATUS"] = "Status Updated successfully."
      render :json => 200 and return
    rescue Exception => e
      Rails.logger.error "Office 365 :: failed to update status. {:account => #{current_account}, :ticket => #{@ticket.id} } :: \n #{e} \n #{e.backtrace}"
      NewRelic::Agent.notice_error(e,{:custom_params => {:account_id => current_account.id, :description => "Unable to update status. : #{e.message}"}})
    end 
    response.headers["CARD-ACTION-STATUS"] = "Status could not be updated."
    render :json => 404 and return
  end

  def priority
    begin
      @ticket.priority = params["priority"]
      @ticket.save!
      response.headers["CARD-ACTION-STATUS"] = "Priority Updated successfully."
      render :json => 200 and return
    rescue Exception => e
      Rails.logger.error "Office 365 :: failed to update priority. {:account => #{current_account}, :ticket => #{@ticket.id} } :: \n #{e} \n #{e.backtrace}"
      NewRelic::Agent.notice_error(e,{:custom_params => {:account_id => current_account.id, :description => "Unable to update priority. : #{e.message}"}})
    end 
    response.headers["CARD-ACTION-STATUS"] = "priority could not be updated."
    render :json => 404 and return
  end

  def agent
    begin
      @ticket.responder_id = current_account.users.find(params["agent"]).id
      @ticket.save!
      response.headers["CARD-ACTION-STATUS"] = "Agent Updated successfully."
      render :json => 200 and return
    rescue Exception => e
      Rails.logger.error "Office 365 :: failed to update agent. {:account => #{current_account.id}, :ticket => #{@ticket.id} } :: \n #{e} \n #{e.backtrace}"
      NewRelic::Agent.notice_error(e,{:custom_params => {:account_id => current_account.id, :description => "Unable to update agent. : #{e.message}"}})
    end 
    response.headers["CARD-ACTION-STATUS"] = "Agent could not be updated."
    render :json => 404 and return
  end

  private

    def set_current_ticket
      begin
        @ticket = current_account.tickets.find(params["ticket_id"].to_i)
      rescue Exception => e
        Rails.logger.error "Unable to assign ticket for the params. {:account => #{current_account.id}, :params_from_outlook => #{params}} :: \n #{e} \n #{e.backtrace}"
        NewRelic::Agent.notice_error(e,{:custom_params => {:account_id => current_account.id, :params => params, :description => "Unable to find ticket for following params. : #{e.message}"}})
        response.headers["CARD-ACTION-STATUS"] = "Request could not be processed successfully. Contact support@freshdesk.com"
        render :json => 404 and return
      end
    end

    def set_current_user(email_id)
      begin
        user = current_account.users.find_by_email(email_id)
        raise "insufficient permission" unless user.agent? and user.has_ticket_permission?(@ticket)
        user.make_current
      rescue Exception => e
        Rails.logger.error "Unable to assign agent for the params. {:account => #{current_account.id}, :params_from_outlook => #{params}} :: \n #{e} \n #{e.backtrace}"
        NewRelic::Agent.notice_error(e,{:custom_params => {:account_id => current_account.id, :params => params, :description => e.message}})
        response.headers["CARD-ACTION-STATUS"] = "Request could not be processed successfully. Contact support@freshdesk.com"
        render :json => 404 and return
      end
    end

    def create_note(ticket, note_body, user)
      source = Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note']
      note_hash = {
        :private => true,
        :user_id => user.id,
        :source => source,
        :note_body_attributes => {
          :body => note_body,
        },
      }
      note = ticket.notes.build(note_hash)
      note.save_note!
      note
    end

    def verify_request
      begin
        result = verify_office_token(request, "https://#{current_account.full_domain}")
        if result[:status] != 200
          Rails.logger.error "Request from microsoft could not be verified successfully."
          response.headers["CARD-ACTION-STATUS"] = "Could not authenticate request. Contact support@freshdesk.com"
          render :json => 404 and return
        else
          set_current_ticket
          set_current_user result[:email_id]
        end
      rescue Exception => e
        Rails.logger.error "Exception while verifying request from Office365 :: #{e.message} \n #{e.backtrace}"
        NewRelic::Agent.notice_error(e,{:custom_params => {:account_id => current_account.id, :description => "Exception while verify request from Office365. : #{e.message}"}})
        response.headers["CARD-ACTION-STATUS"] = "Could not authenticate request. Contact support@freshdesk.com"
        render :json => 404 and return
      end
    end

end