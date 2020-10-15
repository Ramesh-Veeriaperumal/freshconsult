class Integrations::Cti::CustomerDetailsController < ApplicationController
  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:verify_session]
  SECRET_KEY = "3f1fd135e84c2a13c212c11ff2f4b205725faf706345716f4b6996f9f8f2e6472f5784076c4fe102f4c6eae50da0fa59a9cc8cf79fb07ecc1eef62e9d370227f"
  before_filter :check_cti_enabled, :except => [:verify_session]
  
  def fetch
    mobile_number = params[:user][:mobile]
    user = get_user_with_mobile_or_phone(mobile_number)
    mobile_without_code = mobile_number[-10..-1] || mobile_number
    if user.nil? && mobile_without_code != mobile_number
      mobile_number = mobile_without_code
      user = get_user_with_mobile_or_phone(mobile_number)
    end
    href = ""
    if user.blank?
      user_hash = {:mobile => params[:user][:mobile],:avatar => view_context.user_avatar(user, :thumb, "preview_pic circle", {:width => "30px", :height => "30px" })}
    else
      avatar = view_context.user_avatar(user, :thumb, "preview_pic circle", {:width => "30px", :height => "30px" })
      user_tickets = current_account.tickets.permissible(user).requester_active(user).newest(2)
      tickets_json = user_tickets.to_json
      href = "/contacts/" + (user.id).to_s
      user_hash = { :name => user.name, :email => user.email, :mobile => mobile_number, :description => user.description,
      :job_title => user.job_title, :company_name => user.company_name, :tickets => tickets_json,:avatar => avatar,:href => href}
    end
    agent = current_account.user_emails.user_for_email(params[:agent][:email])
    if agent.blank?
      new_user  = current_account.contacts.new 
      status = new_user.signup!({:user => {:email => params[:agent][:email] }}, nil, true)
    end
    respond_to do |format|
      format.json do 
        render :json => {:text => "success","data" => user_hash,"agent_saved" => status || "already exist"}
      end
    end
  end

  def create_note
    rec = params[:recordingUrl]
    params[:remoteId]="" if params[:remoteId]==0
    cti_note_desc = "Support Call between #{current_user.name} and #{params[:number]}<br/><br/>"
    cti_note_desc += "<audio controls><source src=\'#{rec}\' class=\"cti_recording\" type=\"audio/ogg\"/></source></audio>" if rec.present?
    cti_note_desc += "<br/><br/>#{params[:remoteId]}"
    agent_note_desc = "#{params[:msg]}"
    @ticket = current_account.tickets.find_by_display_id(params[:ticketId])
    if @ticket.blank?
      flash[:notice] = t(:'flash.general.create.failure',
                        { :human_name => t(:'cti.note.human_name') })
      return
    end
    note = @ticket.notes.build(
        :note_body_attributes => { :body_html => cti_note_desc },
        :private => false,
        :source => current_account.helpdesk_sources.note_source_keys_by_token["phone"],
        :account_id => current_account.id,
        :user_id => current_user.id
      )
    if note.save_note
      if agent_note_desc.present?
        note2 = @ticket.notes.build(
          :note_body_attributes => { :body_html => agent_note_desc },
          :private => current_account.cti_installed_app_from_cache.configs[:inputs][:add_note_as_private].to_s.to_bool,
          :source => current_account.helpdesk_sources.note_source_keys_by_token['note'],
          :account_id => current_account.id,
          :user_id => current_user.id
        )
        note2.save_note
      end
      flash[:notice] = t(:'cti.create.success.with_link',
      { :human_name => t(:'cti.note.human_name'),
        :link => view_context.comment_path({ 'ticket_id' => note.notable.display_id, 
                                          'comment_id' => note.id }, 
                                        t(:'cti.note.view'), 
                                        { :'data-pjax' => "#body-container" }),
      }).html_safe
    else
      flash[:notice] = t(:'flash.general.create.failure',
                        { :human_name => t(:'cti.note.human_name') })
    end
  end

  def create_ticket
    params[:ticket][:remoteId]="" if params[:ticket][:remoteId]==0
    rec = params[:ticket][:recordingUrl]
    ticket_desc = "Support Call between #{current_user.name} and #{params[:ticket][:number]}<br/><br/>"
    ticket_desc += "<audio controls><source src=\'#{rec}\' class=\"cti_recording\" type=\"audio/ogg\"/></source></audio>" if rec.present?
    ticket_desc += "<br/><br/>#{params[:ticket][:remoteId]}"
    note_desc = "#{params[:ticket][:description]}" if params[:ticket][:description].present?

    user = get_user_with_mobile_or_phone(params[:ticket][:number])

    user = current_account.user_emails.user_for_email(params[:ticket][:email]) if user.nil? && params[:ticket][:email].present?

    if user.blank?
      user  = current_account.contacts.new
      user_param = {
        :user => { 
          :mobile => params[:ticket][:number],
        }
      }
      user_param[:user][:name] = params[:ticket][:requester_name].blank? ? params[:ticket][:number] : params[:ticket][:requester_name]
      user_param[:user][:email] = params[:ticket][:email] if params[:ticket][:email].present?

      unless user.signup!(user_param, nil, true)
        flash[:notice] = t(:'flash.general.create.failure',
                            { :human_name => t(:'cti.ticket.human_name') }) and return
      end
    end
    @ticket = current_account.tickets.build(
                  :source => Helpdesk::Source::PHONE,
                  :requester_id => user.id,
                  :subject  => params[:ticket][:subject],
                  :responder_id => current_user.id,
                  :ticket_body_attributes => { :description_html => ticket_desc }
              )
    if @ticket.save_ticket
      if note_desc.present?
        @note = @ticket.notes.build(
                  :private => current_account.cti_installed_app_from_cache.configs[:inputs][:add_note_as_private].to_s.to_bool,
                  :user_id => current_user.id,
                  :account_id => current_account.id,
                  :source => current_account.helpdesk_sources.note_source_keys_by_token['note'],
                  :note_body_attributes => { :body_html => note_desc }
              )
        @note.save_note
      end
      flash[:notice] = t(:'cti.create.success.with_link',
            { :human_name => t(:'cti.ticket.human_name'),
              :link => view_context.link_to(t(:'cti.ticket.view'),
                helpdesk_ticket_path(@ticket), :'data-pjax' => "#body-container") }).html_safe
    else
      flash[:notice] = t(:'flash.general.create.failure',
                            { :human_name => t(:'cti.ticket.human_name') })
    end
  end

  def verify_session
    req = Hash.from_xml(params[:requestXml])
    pwd = req['request']['password']
    email = req['request']['userId']
     temp=Digest::SHA512.hexdigest("#{SECRET_KEY}::#{email}")
     if temp.eql?(pwd)
     render :xml => {:status => "success", :message => "Auth Successful",:crmSessionId => pwd}.to_xml(:root => "response")
    else
      render :xml => {:status => "failed", :message => "Incorrect Password",:crmSessionId => pwd}.to_xml(:root => "response")
    end
  end

  def ameyo_session
    email = params[:email]
    session=Digest::SHA512.hexdigest("#{SECRET_KEY}::#{email}")
    respond_to do |format|
      format.json do 
        render :json => {:text => "success",:sessionId => session}
      end
    end
  end

  private
  
  def get_user_with_mobile_or_phone(mobile_number)
    mobile_number = mobile_number.to_s
    user = current_account.all_users.where(:deleted => false, :mobile => mobile_number).first
    return user unless user.nil?
    current_account.all_users.where(:deleted => false, :phone => mobile_number).first
  end

  def check_cti_enabled
    render :json =>  {:error => t("integrations.cti.cti_error") }  if current_account.cti_installed_app_from_cache.blank? 
  end

end