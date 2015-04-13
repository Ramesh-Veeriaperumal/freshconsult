class Integrations::Cti::CustomerDetailsController < ApplicationController
  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:verify_session]
  SECRET_KEY = "3f1fd135e84c2a13c212c11ff2f4b205725faf706345716f4b6996f9f8f2e6472f5784076c4fe102f4c6eae50da0fa59a9cc8cf79fb07ecc1eef62e9d370227f"
  
  include ApplicationHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::AssetTagHelper
  
  def fetch
    mobile_number = params[:user][:mobile]
    mobile_number = mobile_number[-10..-1] || mobile_number
    user = current_account.users.with_contact_number(mobile_number).first
    href = ""
    if user.blank?
      user_hash = {:mobile => mobile_number,:avatar => user_avatar(user, :thumb, "preview_pic", {:width => "30px", :height => "30px" })}
    else
      avatar = user_avatar(user, :thumb, "preview_pic", {:width => "30px", :height => "30px" })
      user_tickets = current_account.tickets.permissible(user).requester_active(user).newest(2)
      tickets_json = user_tickets.to_json
      href = "/contacts/" + (user.id).to_s
      user_hash = { :name => user.name, :email => user.email, :mobile => mobile_number, :description => user.description,
      :job_title => user.job_title, :company_name => user.company_name, :tickets => tickets_json,:avatar => avatar,:href => href}
    end
    agent = current_account.users.find_by_email(params[:agent][:email])
    if agent.blank?
      new_user  = current_account.users.new 
      new_user.email = params[:agent][:email]
      status = new_user.save
    end
    respond_to do |format|
      format.json do 
        render :json => {:text => "success","data" => user_hash,"agent_saved" => status || "already exist"}
      end
    end
  end

  def create_note
    rec = params[:recordingUrl]
    note_desc = "#{params[:msg]}<br/><audio controls><source src=\'#{rec}\' class=\"cti_recording\" type=\"audio/ogg\"/></source></audio><br/>#{params[:remoteId]}"
    @ticket = current_account.tickets.find_by_display_id(params[:ticketId])
    if @ticket.blank?
      flash[:notice] = t(:'flash.general.create.failure',
                        { :human_name => t(:'cti.note.human_name') })
      return
    end
    note = @ticket.notes.build(
        :note_body_attributes => { :body_html => note_desc },
        :private => false,
        :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["phone"],
        :account_id => current_account.id,
        :user_id => current_user.id
      )
    if note.save_note
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
    # respond_to do |format|
    #   format.json do 
    #     render :json => {:type => "note",:Id => note.id }
    #   end
    # end
  end

  def create_ticket
    rec = params[:ticket][:recordingUrl]
    ticket_desc = "#{params[:ticket][:description]}<br/><audio controls><source src=\'#{rec}\' class=\"cti_recording\" type=\"audio/ogg\"/></source></audio><br/>#{params[:ticket][:remoteId]}"
    user = current_account.users.find_by_email(params[:ticket][:email])
    if user.blank?
      user  = current_account.users.new
      user.name = params[:ticket][:requester_name].blank? ? params[:ticket][:number] : params[:ticket][:requester_name]
      user.mobile = params[:ticket][:number]
      user.email = params[:ticket][:email] unless params[:ticket][:email].blank?
      if !user.save
        flash[:notice] = t(:'flash.general.create.failure',
                            { :human_name => t(:'cti.ticket.human_name') })
        return
      end
    end
    @ticket = current_account.tickets.build(
                  :source => TicketConstants::SOURCE_KEYS_BY_TOKEN[:phone],
                  :requester_id => user.id,
                  :subject  => params[:ticket][:subject],
                  :responder_id => current_user.id,
                  :ticket_body_attributes => { :description_html => ticket_desc }
              )
    if @ticket.save_ticket
      flash[:notice] = t(:'cti.create.success.with_link',
          { :human_name => t(:'cti.ticket.human_name'),
            :link => view_context.link_to(t(:'cti.ticket.view'),
              helpdesk_ticket_path(@ticket), :'data-pjax' => "#body-container") }).html_safe
    else
      flash[:notice] = t(:'flash.general.create.failure',
                            { :human_name => t(:'cti.ticket.human_name') })
    end
    # respond_to do |format|
    #   format.js
    #   format.json do 
    #     render :json => {:type => "ticket",:Id => @ticket.id}
    #   end
    # end
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
end