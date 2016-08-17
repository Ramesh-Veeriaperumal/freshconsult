class Integrations::Cti::ScreenPopController < ApplicationController
  include Integrations::CtiHelper
  include Redis::RedisKeys
  include Redis::IntegrationsRedis
  helper Integrations::CtiHelper
  before_filter :load_installed_app

  APP_NAME = Integrations::Constants::APP_NAMES[:cti]
  TICKET_SELECT_FIELDS = %i(display_id description subject status_name)

  def contact_details
    requester = current_account.all_users.find(params[:requester_id])
    render :partial => "requester_info",:locals =>{:requester => requester }
  end

  def recent_tickets
    tickets = current_account.tickets.where(:requester_id => params[:requester_id]).
              permissible(current_user).visible.newest(3).includes(:ticket_status)
    tickets_count = current_account.tickets.where(:requester_id => params[:requester_id]).permissible(current_user).visible.size
    render :partial => "recent_tickets",:locals => {:tickets => tickets, :requester => params[:requester_id], :tickets_count => tickets_count }
  end

  def link_to_existing
    if params[:ticket_id].present? && params[:call_id].present?
      ticket = current_account.tickets.where(:display_id => params[:ticket_id]).first
      call = current_account.cti_calls.where(:id => params[:call_id]).first
      call.status = Integrations::CtiCall::AGENT_CONVERTED
      note = nil
      if call.options[:new_ticket]
        ticket = call.recordable
      else
        note_body = "#{cti_header_msg(call)} #{cti_call_url_msg(call)} #{cti_call_info_msg(call)}"
        note = create_note(ticket, note_body, current_user, Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["phone"])
        call.recordable = note
        call.save!
      end
      if(params[:note_body].present?)
        agent_note = create_note(ticket, params[:note_body], current_user, Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"], @installed_app.configs_call_note_private.to_bool)
        #A Small Hack to maintain the order of the notes as mysql DateTime precision is only upto seconds.
        if note.present? && note.created_at.to_i == agent_note.created_at.to_i
          agent_note.update_column(:created_at, agent_note.created_at + 1.seconds)
          agent_note.update_column(:updated_at, agent_note.updated_at + 1.seconds)
        end
      end
      clear_pop
      render :json => {:ticket_path => helpdesk_ticket_path(ticket)}, :status => :ok
    else
      render :json => {:msg => "Ticket id or call id Not found"}, :status => :not_found
    end
  end

  def link_to_new
    begin
      if params[:call_id].present?
        call = current_account.cti_calls.where(:id => params[:call_id]).first
        req = call.requester
        if params[:requester_name].present? && req.name != params[:requester_name]
          req.name = params[:requester_name]
          req.save!
        end
        link_call_to_new_ticket(call, false, params[:subject])
        create_note(call.recordable, params[:note_body], current_user, Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"], @installed_app.configs_call_note_private.to_bool) if params[:note_body].present?
        call.status = Integrations::CtiCall::AGENT_CONVERTED
        call.save!
        render :json => {:ticket_path => helpdesk_ticket_path(call.recordable)}, :status => :ok
        clear_pop
      else
        render :json => {:msg => "Call Id not present"}, :status => :not_found
      end
    rescue => e
      Rails.logger.debug("Ticket creation failed for call id #{params[:call_id]}: #{e.message} \n#{e.backtrace.join("\n")}")
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Ticket creation failed for call id #{params[:call_id]}: #{e.message}", :account_id => current_account.id}})
      render :json => {:msg => "Ticket Creation Failed"}, :status => :not_found
    end
  end

  def add_note_to_new
    if params[:call_id].present?
      call = current_account.cti_calls.where(:id => params[:call_id]).first
      call.status = Integrations::CtiCall::IGNORED
      if params[:note_body].present?
        create_note(call.recordable, params[:note_body], current_user, Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"], @installed_app.configs_call_note_private.to_bool)
        call.status = Integrations::CtiCall::AGENT_CONVERTED
      end
      call.save!
      clear_pop
      render :json => {:ticket_path => helpdesk_ticket_path(call.recordable)}, :status => :ok
    else
      render :json => {:msg => "Call Id not present"}, :status => :not_found
    end
  end

  def ignore_call
    if params[:call_id].present?
      call = current_account.cti_calls.where(:id => params[:call_id]).first
      call.status = Integrations::CtiCall::IGNORED
      call.save!
      clear_pop
      render :json => {:msg => "Ignored call successfully"}, :status => :ok
    else
      render :json => {:msg => "Call Id not present"}, :status => :not_found
    end
  end

  def set_pop_open
    if params[:call_id].present?
      call = current_account.cti_calls.where(:id => params[:call_id]).first
      call.status = Integrations::CtiCall::VIEWING
      call.save!
      set_cti_redis_value("1")
      render :json => {:msg => "successs"}, :status => :ok
    else
      render :json => {:msg => "Call Id not present"}, :status => :not_found
    end
  end

  def ongoing_call
    call = current_account.cti_calls.where(:responder_id => current_user.id).order('created_at DESC').first
    if call.present? && ![Integrations::CtiCall::AGENT_CONVERTED, Integrations::CtiCall::IGNORED].include?(call.status)
      if Integrations::CtiCall::VIEWING == call.status || call.created_at.utc > (Time.now.utc - 30.seconds)
        ticket_id = call.recordable.is_a?(Helpdesk::Ticket) ? call.recordable.display_id : call.options[:ticket_id]
        render :json => {:requester_id => call.requester_id, :ticket_id => ticket_id, :id => call.id, :new_ticket => call.options[:new_ticket]} and return
      end
    end
    render :json => {:msg => "No calls"}, :status => :not_found
  end

  def phone_numbers
    render :json => current_account.cti_phones.select([:id, :phone]).map { |cti_phone| {:id => cti_phone.id, :phone => cti_phone.phone} }
  end

  def set_phone_number
    cti_phone = current_account.cti_phones.find(params[:id])
    cti_phone.agent_id = current_user.id
    if cti_phone.save
      cti_phone_redis_key = INTEGRATIONS_CTI_OLD_PHONE % { :account_id => current_account.id, :user_id => current_user.id }
      set_integ_redis_key(cti_phone_redis_key, cti_phone.id)
      render :json => {:msg => "Cti Phone Successfully changed"}, :status => :ok
    else
      render :json => {:msg => "Failed to Change Cti Phone"}, :status => :not_found
    end
  end

  def click_to_dial
    installed_app = current_account.installed_applications.with_name(Integrations::Constants::APP_NAMES[:cti]).first
    inputs = installed_app.configs[:inputs].symbolize_keys
    ticket = nil
    if(params[:ticket_id].present?)
      ticket = current_account.tickets.where(:display_id => params[:ticket_id]).first
    end
    requester_id = ticket.present? ? ticket.requester_id : params[:requester_id]
    agent_number = current_user.cti_phone.present? ? current_user.cti_phone.phone : nil

    if inputs[:click_to_dial].to_bool
      http_params = {}
      if inputs[:cti_ctd_req_auth].to_bool
        if inputs[:cti_ctd_user_name].present?
          http_params[:username] = inputs[:cti_ctd_user_name]
          http_params[:password] = installed_app.configsdecrypt_password
        else
          http_params[:username] = inputs[:cti_ctd_api]
          http_params[:password] = "X"
        end
      end
      http_params[:method] = inputs[:cti_ctd_method]
      http_params[:domain] = Liquid::Template.parse(inputs[:cti_ctd_url].gsub(/\n+/, "")).render( 'requester_number' => params[:requester_number], 'agent_number' => agent_number, 'agent_id' => current_user.id, 'ticket_id' => params[:ticket_id] || "", 'requester_id' => requester_id)
      http_params[:body] = Liquid::Template.parse(inputs[:cti_ctd_content].gsub(/\n+/, "")).render( 'requester_number' => params[:requester_number], 'agent_number' => agent_number || "null", 'agent_id' => current_user.id, 'ticket_id' => params[:ticket_id] || "null", 'requester_id' => requester_id) if inputs[:cti_ctd_method] == "post"
      http_params[:content_type] = inputs[:cti_ctd_encoding] if inputs[:cti_ctd_method] == "post"
      httpRequestProxy = HttpRequestProxy.new
      http_resp = httpRequestProxy.fetch(http_params,nil)
      render :json => {:msg => http_resp[:text]}, :status => http_resp[:status]
    else
      render :json => {:msg => "Click to dial is not enabled"}, :status => :bad_request
    end
  end

  private

  def load_installed_app
    @installed_app = current_account.installed_applications.with_name(APP_NAME).first
    render :json => {:message => "Cti Integration not enabled"}, :status => :not_found unless @installed_app
  end

  def set_cti_redis_value(value)
    cti_redis_key = INTEGRATIONS_CTI % { :account_id => current_account.id, :user_id => current_user.id }
    Rails.logger.debug cti_redis_key
    set_integ_redis_key(cti_redis_key, value)
  end

  def clear_pop
    set_cti_redis_value("0")
  end
end
