class Integrations::Cti::CustomerDetailsController < ApplicationController
  SECRET_KEY = "3f1fd135e84c2a13c212c11ff2f4b205725faf706345716f4b6996f9f8f2e6472f5784076c4fe102f4c6eae50da0fa59a9cc8cf79fb07ecc1eef62e9d370227f"
  skip_before_filter  :check_privilege, :verify_authenticity_token, :only => [:verify_session, :save_ticket_popup]

  # include Integrations::Cti::NodeEvents
  include ApplicationHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::AssetTagHelper
  
  def fetch
    mobile_number = params[:mobile]
    usr = User.find(:first,:conditions => ["mobile=? or phone=?",params[:mobile],params[:mobile]])
    href = ""
    if usr.nil?
      usr_hash = {:mobile => params[:mobile],:avatar => user_avatar(usr, :thumb, "preview_pic", {:width => "30px", :height => "30px" })}
    else
      avatar = user_avatar(usr, :thumb, "preview_pic", {:width => "30px", :height => "30px" })
      tkt = current_account.tickets.permissible(current_user)
      params[:requester_id] = usr.id
      @items = tkt.select { |item| item.requester_id == usr.id }
      @items.sort!{|a,b| b.updated_at <=> a.updated_at}
      @items = @items.take(2)
      json = "["; sep=""
            @items.each { |tic| 
            json << sep + tic.to_json({}, false)[19..-2]; sep=","
            }
      href = "/contacts/" + (usr.id).to_s
      usr_hash = { :name => usr.name, :email => usr.email, :mobile => mobile_number, :description => usr.description,
      :job_title => usr.job_title, :company_name => usr.company_name, :tickets => json,:avatar => avatar,:href => href}
      
    end
    agent = User.find_by_email(params[:email])
    if agent.nil?
      @user  = current_account.users.new 
      @user.email = params[:email]
      status = @user.save
    end
    if(!request.xhr? && !(agent.nil?))
      # publish_user_details(agent, usr_hash, params[:email]) 
    end
    respond_to do |format|
      format.json do 
        render :json => {:text => "success","data" => usr_hash,"agent_saved" => status || "already exist"}
      end
    end
  end

  def save_ticket_popup
    mobile_number = params[:phone]
    usr = User.find(:first,:conditions => ["mobile=? or phone=?",params[:mobile],params[:mobile]])
    if usr.nil?
      name = mobile_number
    else 
      name = usr.name
    end
    agent = User.find_by_email(URI.unescape(params[:userId]))
    if agent.nil?
      @user  = current_account.users.new 
      @user.email = params[:userId]
      status = @user.save
    end
    if(!(request.xhr?) && !(agent.nil?))
        # publish_show_popup(agent,{:email => params[:userId],:crtObjectId => params[:crtObjectId],:cust_name => name})
    end
    respond_to do |format|
      format.json do 
        render :json => {:text => "success","agent_saved" => status || "already exist"}
      end
    end
  end

  def create_note
    rec = params[:recordingUrl]
    note_desc = params[:msg] + '<br/>'
    note_desc = '<audio controls><source src="'+"#{rec}"+'" class="cti_recording" type="audio/ogg"/></source></audio>'
    @ticket = current_account.tickets.find_by_display_id(params[:ticketId])
        note = @ticket.notes.build(
            :note_body_attributes => { :body_html => note_desc },
            :private => false,
            :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["phone"],
            :account_id => current_account.id,
            :user_id => current_user.id
          )
        status = note.save_note
        if status
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
         # render :template => 'integrations/cti/customer_details/create_note.rjs' and return
        
  end

  def create_ticket
    rec = params[:ticket][:recordingUrl]
    ticket_desc = params[:ticket][:description] + '<br/>'
    ticket_desc = ticket_desc + '<audio controls><source src="'+"#{rec}"+'" class="cti_recording" type="audio/ogg"/></source></audio>'
    @usr = User.find_by_email(params[:email])
    if @usr.nil?
      @usr  = current_account.users.new 
      @usr.name = params[:ticket][:number]
      @usr.mobile = params[:ticket][:number]
      @usr.email = params[:ticket][:email] unless params[:ticket][:email].blank?
      @usr.save
    end
    @ticket = current_account.tickets.build(
                  :source => TicketConstants::SOURCE_KEYS_BY_TOKEN[:phone],
                  :requester_id => @usr.id,
                  :subject  => params[:ticket][:subject],
                  :ticket_body_attributes => { :description_html => ticket_desc }
              )
    status = @ticket.save_ticket
    if status
      flash[:notice] = t(:'cti.create.success.with_link',
          { :human_name => t(:'cti.ticket.human_name'),
            :link => @template.link_to(t(:'cti.ticket.view'),
              helpdesk_ticket_path(@ticket), :'data-pjax' => "#body-container") }).html_safe
    else
      flash[:notice] = t(:'flash.general.create.failure',
                            { :human_name => t(:'cti.ticket.human_name') })
    end
       # render :template => 'integrations/cti/customer_details/create_ticket.rjs' and return
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

  def get_session
    email = params[:email]
    session=Digest::SHA512.hexdigest("#{SECRET_KEY}::#{email}")
    respond_to do |format|
      format.json do 
        render :json => {:text => "success",:sessionId => session}
      end
    end
  end

end