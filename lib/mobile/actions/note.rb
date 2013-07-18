# encoding: utf-8
module Mobile::Actions::Note
  
  def body_mobile
    body_html.index(">\n<div class=\"freshdesk_quote\">").nil? ? 
    body_html : body_html.slice(0..body_html.index(">\n<div class=\"freshdesk_quote\">"))
    body_html.gsub(/href=/,"target='_blank' href=");
  end

  def formatted_created_at(format = "%B %e %Y @ %I:%M %p")
    format = format.gsub(/.\b[%Yy]/, "") if (created_at.year == Time.now.year)
    created_at.strftime(format)
  end

  def to_mob_json
    json_include = {
      :user => {
        :only => [ :name, :email, :id ],
        :methods => [ :avatar_url ]
      },
      :attachments => {
        :only => [ :content_file_name, :id, :content_content_type, :content_file_size ]
      }
    }
    options = {
      :include => json_include
    }
    to_json(options)
  end
end
