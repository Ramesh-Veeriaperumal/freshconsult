class Integrations::Cti::CustomerDetailsController < ApplicationController

  include ApplicationHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::AssetTagHelper
  
  def fetch
    mobile_number = params[:user][:mobile]
    if mobile_number.length>10
      mobile_number = mobile_number[-10,10]
    end
    user = User.with_contact_number(mobile_number).first
    href = ""
    if user.blank?
      user_hash = {:mobile => mobile_number,:avatar => user_avatar(user, :thumb, "preview_pic", {:width => "30px", :height => "30px" })}
    else
      avatar = user_avatar(user, :thumb, "preview_pic", {:width => "30px", :height => "30px" })
      user_tickets = current_account.tickets.permissible(user).requester_active(user).newest(2)
      json = user_tickets.to_json
      href = "/contacts/" + (user.id).to_s
      user_hash = { :name => user.name, :email => user.email, :mobile => mobile_number, :description => user.description,
      :job_title => user.job_title, :company_name => user.company_name, :tickets => json,:avatar => avatar,:href => href}
    end
    agent = User.find_by_email(params[:agent][:email])
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
    note_desc = "#{params[:msg]}<br/><audio controls><source src=\'#{rec}\' class=\"cti_recording\" type=\"audio/ogg\"/></source></audio>"
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
        :link => @template.comment_path({ 'ticket_id' => note.notable.display_id, 
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
    rec = params[:ticket][:recordingUrl]
    ticket_desc = "#{params[:ticket][:description]}<br/><audio controls><source src=\'#{rec}\' class=\"cti_recording\" type=\"audio/ogg\"/></source></audio>"
    user = User.find_by_email(params[:ticket][:email])
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
                  :ticket_body_attributes => { :description_html => ticket_desc }
              )
    if @ticket.save_ticket
      flash[:notice] = t(:'cti.create.success.with_link',
          { :human_name => t(:'cti.ticket.human_name'),
            :link => @template.link_to(t(:'cti.ticket.view'),
              helpdesk_ticket_path(@ticket), :'data-pjax' => "#body-container") }).html_safe
    else
      flash[:notice] = t(:'flash.general.create.failure',
                            { :human_name => t(:'cti.ticket.human_name') })
    end
  end
end