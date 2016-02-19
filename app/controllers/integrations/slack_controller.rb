#Remove when Slack v1 is obselete.
require 'json'
class Integrations::SlackController < ApplicationController
  include Integrations::Slack::SlackConfigurationsUtil
  include  Integrations::Slack::Constant

  skip_before_filter :check_privilege, :verify_authenticity_token
  before_filter :verify_installed_app, :verify_authentication, :only => [:create_ticket]

  def create_ticket
    channel = params[:channel_id]
    token_val = params[:text]
    url = "#{SLACK_REST_API[:history]}token=#{token_val}&channel=#{channel}"
    text = response_handle(url)
    unless text["ok"]
      Rails.logger.debug "Invalid channel #{channel} or Invalid slack token #{token_val}"
      render :json => {:success => false}
    end
    data = text["messages"].reverse
    msg = ""
    user_details, user_email = user_list_and_user_email(token_val)
    subject = ticket_subject(data,user_details)
    msg, formated_msg = extract_msg_from_json(data, user_details)
    ticket_create_in_fd(user_email, subject, msg, formated_msg)
  end

  private

  def extract_msg_from_json(data, user_details)
    msg = ""
    formated_msg = ""
    data.each do |key|
      if key["text"] 
        user_index = nil
        user_no = key["user"]
        user_details.each_with_index do |user, index| 
          user_index = index if user["id"] == user_no
        end
    
        if user_index and user_no
          user_name = user_details[user_index]["name"]
        elsif key["username"]
          user_name = key["username"] 
        elsif key["user"] == SLACK_BOT
          user_name = "slackbot"
        elsif key["user"].nil?
          Rails.logger.debug "ERROR in finding user in slack #{key}"
        end
        key["text"] = message_formatting(key["text"])
        msg = msg + "#{user_name}" + ":"
        formated_msg = formated_msg + "<strong>#{user_name}</strong>" + ":"
        msg = msg + key["text"] + "\n"
        formated_msg = formated_msg + key["text"] + "\n"
      else
        key["message"]["text"] = message_formatting(key["message"]["text"])
        msg = msg + key["message"]["text"] + "\n"
        formated_msg = formated_msg + key["message"]["text"] + "\n"
      end
    end
    formated_msg = formated_msg.gsub("\n","<br>")
    return msg, formated_msg
  end

  def user_list_and_user_email(token_val)
    ticket_creator_id = params["user_id"]
    user_url = "#{SLACK_REST_API[:user_list]}token=#{token_val}"
    users_info = response_handle(user_url)
    users = users_info["members"]
    user_email = ""
    user_details = []
    users.each_with_index do |user,i|
      user_email = user["profile"]["email"] if user["id"] == ticket_creator_id
      user_details[i] = { 
        "name" => user["name"],
        "id" => user["id"]
      }
    end
    return user_details, user_email
  end

  def ticket_subject(data, user_details)
    data.each do |key|
      if key["user"] && key["user"]!= params[:user_id] && key["user"]!= SLACK_BOT
        user_details.each do |user|
          if user["id"] == key["user"]
              return "#{t('integrations.slack_msg.chat')} #{user['name']} on #{Time.now.strftime("%a,#{Time.new.day.ordinalize} %b %Y")}"
          end    
        end   
      end
    end  
    return "#{t('integrations.slack_msg.default_chat')} #{params['user_name']} on  #{Time.now.strftime("%a,#{Time.new.day.ordinalize} %b %Y")}"
  end

  def ticket_create_in_fd(user_email, subject, msg, formated_msg)
    ticket = current_account.tickets.build(
      :email    => user_email ,
      :priority => TicketConstants::PRIORITY_KEYS_BY_NAME["low"], 
      :status   => Helpdesk::Ticketfields::TicketStatus::OPEN, 
      :subject => subject,
      :ticket_body_attributes => { 
        :description => msg, 
        :description_html => "<div>#{formated_msg}</div>" 
      })

    if ticket.save
      Rails.logger.debug "Success in creating ticket"
    else
      Rails.logger.debug "Error in creating ticket"
    end
    render :json => {:head => :ok}
  end

  def message_formatting(text)
    text.gsub!("&","")
    text.gsub!("<","")
    text.gsub!(">","")
    text
  end

  def verify_installed_app
    app = current_account.installed_applications.with_name("slack")
    unless app.present?
      render :json => {:success => false} and return
    end
  end

  def verify_authentication
    api_key = params[:api_key]
    api_key_found = current_account.users.find_by_single_access_token(api_key)

    token_val = params[:text]
    channel = params[:channel_id]
    url = "#{SLACK_REST_API[:test]}token=#{token_val}"
    response = response_handle(url)

    if response["ok"]
      if (params[:channel_name] != "directmessage")  
        raise_error_in_slack(token_val, channel, "wrong_channel")
      elsif (api_key_found.nil?)
        raise_error_in_slack(token_val, channel, "invalid_api_key")
      end
    else
      Rails.logger.debug "Invalid token passed in parameter"
      render :json => {:success => false}
    end      
  end  

  def raise_error_in_slack(token_val, channel, error)
    msg = t("integrations.slack_msg.#{error}")
    url = "#{SLACK_REST_API[:postMessage]}token=%s&channel=%s&username=%s&icon_url=%s&text=%s" % [token_val,channel,USERNAME,ICON_URL,msg]
    response = response_handle(url)
    render :json => {:head => :ok }
  end
end

