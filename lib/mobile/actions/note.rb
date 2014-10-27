# encoding: utf-8
module Mobile::Actions::Note
  
  include Mobile::Actions::Push_Notifier
  
  def body_mobile
    body_html.index(">\n<div class=\"freshdesk_quote\">").nil? ? 
    body_html : body_html.slice(0..body_html.index(">\n<div class=\"freshdesk_quote\">"))
    body_html.gsub(/href=/,"target='_blank' href=");
  end

  def formatted_created_at(format = "%B %e %Y @ %I:%M %p")
    format = format.gsub(/.\b[%Yy]/, "") if (created_at.year == Time.now.year)
    created_at.strftime(format)
  end

  def call_details
    call = self.freshfone_call
    {:call_url => recording_audio_url, :call_duration => call.call_duration, :twilio_url => call.recording_url} if call.present?
  end  

  def to_mob_json
    json_include = {
      :user => {
        :only => [ :name, :email, :id ],
        :methods => [ :avatar_url ]
      },
      :attachments => {
        :only => [ :content_file_name, :id, :content_content_type, :content_file_size ]
      },
      :schema_less_note => {
        :only => [:from_email , :to_emails , :cc_emails , :bcc_emails]
      }
    }
    options = {
      :include => json_include,
      :methods => [ :formatted_created_at, :call_details ]
    }
    to_json(options)
  end

  def recording_audio_url
    return if self.freshfone_call.recording_audio.nil?
    AwsWrapper::S3Object.url_for(self.freshfone_call.recording_audio.content.path('original'), self.freshfone_call.recording_audio.content.bucket_name,
                                :expires => 3600.seconds, :secure => true, :response_content_type => self.freshfone_call.recording_audio.content_content_type)
  end
end
