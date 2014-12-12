# encoding: utf-8
module Mobile::Actions::Ticket
  
  include ActionView::Helpers::DateHelper
  include Mobile::Actions::Push_Notifier
  
  NOTES_OPTION = {
      :only => [ :created_at, :user_id, :id, :private, :deleted ],
      :include => {
        :user => {
          :only => [ :name, :email, :id ],
          :methods => [ :avatar_url, :is_agent, :is_customer ]
        },
        :attachments => {
          :only => [ :content_file_name, :id, :content_content_type, :content_file_size ]
        }
      },
      :methods => [ :body_mobile, :source_name, :formatted_created_at ]
  }

  JSON_INCLUDE = {
    :responder => {
      :only => [ :name, :email, :id ],
      :methods => [ :avatar_url ]
    },
    :requester => {
      :only => [ :name, :email, :id, :is_agent, :is_customer, :twitter_id  ],
      :methods => [ :avatar_url, :is_customer ]
    },
    :attachments => {
      :only => [ :content_file_name, :id, :content_content_type, :content_file_size ]
    },
    :fb_post => {
      :include => {
        :facebook_page => {
          :only => [ :id, :page_name ]
        }
      }
     }
  }

  def to_mob_json(only_public_notes=false, include_notes=true)

    json_inlcude = {
      :responder => {
        :only => [ :name, :email, :id ],
        :methods => [ :avatar_url ]
      },
      :requester => {
        :only => [ :name, :email, :id, :is_agent, :is_customer, :twitter_id  ],
        :methods => [ :avatar_url, :is_customer ]
      },
      :attachments => {
        :only => [ :content_file_name, :id, :content_content_type, :content_file_size ]
      },
      :fb_post => {
        :include => {
          :facebook_page => {
            :only => [ :id, :page_name ]
          }
        }
      }
    }
    if only_public_notes
     json_inlcude[:public_notes] = NOTES_OPTION 
    else if include_notes
     json_inlcude[:notes] = NOTES_OPTION
	 end
    end
    options = {
      :only => [ :id, :display_id, :subject, :description_html, 
                 :deleted, :spam, :cc_email, :due_by, :created_at, :updated_at ],
      :methods => [ :status_name, :priority_name, :requester_name, :responder_name, 
                    :source_name, :is_closed, :to_emails, :to_cc_emails,:conversation_count, 
                    :selected_reply_email, :from_email, :is_twitter, :is_facebook,
                    :fetch_twitter_handle, :fetch_tweet_type, :is_fb_message, :formatted_created_at , 
                    :ticket_notes, :ticket_sla_status, :call_details],
      :include => json_inlcude
    }
    to_json(options,false) 
  end
  
	def to_mob_json_index
    options = { 
      :only => [ :id, :display_id, :subject, :priority, :status, :updated_at],
      :methods => [ :ticket_subject_style,:ticket_sla_status, :status_name, :priority_name, :source_name, :requester_name,
                    :responder_name, :need_attention, :pretty_updated_date ,:ticket_current_state]
    }
    to_json(options,false) 
  end
  
	def to_mob_json_search
    options = { 
      :only => [ :id,:display_id,:subject,:description,:priority],
      :methods => [ :summary_count,:ticket_subject_style,:ticket_sla_status, :status_name, :requester_name ]
    }
    to_json(options,false)
  end

  def to_mob_json_merge_search
    options = { 
      :only => [ :id, :display_id, :subject, :created_at ],
      :methods => [ :requester_name ]
    }
    as_json(options)
  end

  def formatted_created_at(format = "%B %e %Y @ %I:%M %p")
    format = format.gsub(/.\b[%Yy]/, "") if (created_at.year == Time.now.year)
    created_at.strftime(format)
  end

  def pretty_updated_date
    distance_of_time_in_words_to_now(updated_at) + " ago"
  end

  def ticket_current_state
    ticket_current_state = self.ticket_states.current_state
    t("ticket.ticket_user_list_status_"+ticket_current_state,:time_ago => time_ago_in_words(self.ticket_states.send(ticket_current_state)))
  end

  def ticket_sla_status
    closed_status = Helpdesk::TicketStatus.onhold_and_closed_statuses_from_cache(account)
    sla_status(self,closed_status);
  end
  
  def ticket_subject_style
    closed_status = Helpdesk::TicketStatus.onhold_and_closed_statuses_from_cache(account)
    subject_style(self,closed_status)
  end

  def fetch_tweet_type
    tweet.tweet_type unless tweet.blank?
  end

  def call_details
    call = self.freshfone_call
    {:call_url => recording_audio_url, :call_duration => call.call_duration, :twilio_url => call.recording_url} if call.present?
  end

  def recording_audio_url
    return if self.freshfone_call.recording_audio.nil?
    AwsWrapper::S3Object.url_for(self.freshfone_call.recording_audio.content.path('original'), self.freshfone_call.recording_audio.content.bucket_name,
                                :expires => 3600.seconds, :secure => true, :response_content_type => self.freshfone_call.recording_audio.content_content_type)
  end
end
