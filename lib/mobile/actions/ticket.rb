module Mobile::Actions::Ticket
  
  include ActionView::Helpers::DateHelper

  NOTES_OPTION = {
      :only => [ :created_at, :user_id, :id, :private ],
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

  def to_mob_json(only_public_notes=false)

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
    else 
     json_inlcude[:notes] = NOTES_OPTION
    end
    options = {
      :only => [ :id, :display_id, :subject, :description, :description_html, 
                 :deleted, :spam, :cc_email, :due_by, :created_at, :updated_at ],
      :methods => [ :status_name, :priority_name, :requester_name, :responder_name, 
                    :source_name, :is_closed, :to_cc_emails,:conversation_count, 
                    :selected_reply_email, :from_email, :is_twitter, :is_facebook, 
                    :fetch_twitter_handle, :is_fb_message, :formatted_created_at ],
      :include => json_inlcude
    }
    to_json(options,false) 
  end

  def formatted_created_at(format = "%B %e %Y @ %I:%M %p")
    format = format.gsub(/.\b[%Yy]/, "") if (created_at.year == Time.now.year)
    created_at.strftime(format)
  end

  def pretty_updated_date
    distance_of_time_in_words_to_now(updated_at) + " ago"
  end
end