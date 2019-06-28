# encoding: utf-8
class Integrations::LogmeinController < ApplicationController
  include Redis::RedisKeys
  include Redis::IntegrationsRedis
  include Integrations::AppsUtil

  LOGMEIN_CONSTANT = ["ChatLog","Note","SessionID","TechName","TechEmail","Platform","WorkTime"]

  skip_before_filter :check_privilege, :verify_authenticity_token

  def rescue_session
    tracking = params['Tracking0'] || (params["session"] || {})["tracking0"]
    unless tracking.blank?
      chat_params = params['Tracking0'] ? process_old_params(params) : params["session"]
      redis_val = tracking.split(":")
      redis_key = tracking.gsub(/:\w*$/, "")
      secret = redis_val[3]
      ticket_id = redis_val[2]
      account_id = redis_val[1]
      Rails.logger.debug "Adding logging session. Redis Key #{redis_key}"
      redis_key_string = get_integ_redis_key(redis_key)
      acc_ticket = JSON.parse(redis_key_string) unless redis_key_string.nil?
      unless acc_ticket.blank?
        if (acc_ticket["md5secret"] == secret)
          note_head = '<b>' + t("integrations.logmein.note.header") + ' </b> <br />'
          chatlog = chat_params["chatlog"].gsub(/\n/, "<br />") unless chat_params["chatlog"].blank?
          tech_notes =  chat_params["note"].gsub(/\n/, "<br />") unless chat_params["note"].blank?
          note_body = t("integrations.logmein.note.session_id") + " : " + chat_params["sessionid"] + "<br />"
          note_body += t("integrations.logmein.note.tech_name") + " : " + chat_params["techname"] + "<br />"
          note_body += t("integrations.logmein.note.tech_email") + " : " + chat_params["techemail"] + "<br /><br />"
          note_body += t("integrations.logmein.note.platform") + " : " + chat_params["platform"] + "<br />"
          note_body += t("integrations.logmein.note.work_time") + " : " + chat_params["worktime"] + "<br /><br />"
          note_body += "<b>" + t("integrations.logmein.note.chatlog")+ "</b>" + ("<div class = 'logmein_chatlog'>" + chatlog + "</div>") unless chat_params["chatlog"].blank?
          note_body += ("<b>" +  t("integrations.logmein.note.tech_notes") + "</b>" + ("<div class = 'logmein_technotes'>" + tech_notes + "</div>")) unless tech_notes.blank?
          ticket = Helpdesk::Ticket.find_by_id_and_account_id(ticket_id, account_id)
          unless ticket.blank?
              note = ticket.notes.build(
                :note_body_attributes => {:body_html => note_head + note_body},
                :private => true ,
                :incoming => true,
                :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"],
                :account_id => account_id,
                :user_id => acc_ticket["agent_id"] 
               )
               note.save_note!
            end     
            remove_integ_redis_key(redis_key) 
        end 
      end
    end
    render :json => {:status => "Success" }
  end

  #support both logmein  version
  def process_old_params(params)
    chat_params = {}
    LOGMEIN_CONSTANT.each do |key| 
      chat_params[key.downcase] = params[key]
    end
    chat_params
  end

  def update_pincode
    begin
      redis_key = "INTEGRATIONS_LOGMEIN:#{params['account_id']}:#{params['ticket_id']}"
        cache_val = get_integ_redis_key(redis_key)
        set_integ_redis_key(redis_key, params['logmein_session'])
      render :json => {:status => "Success"}  
    rescue Exception => e
      render :json => {:error => e}
    end
    
  end

end
