module Helpdesk::NotifierFormattingMethods

  def formatted_subject(ticket)
    "Re: #{ticket.encode_display_id} #{ticket.subject}"
  end

  def fwd_formatted_subject(ticket)
    "Fwd: #{ticket.encode_display_id} #{ticket.subject}"
  end

  def formatted_export_subject(params)
    filter = "export_data.#{params[:ticket_state_filter]}"
    filter = I18n.t(filter)
    I18n.t('export_data.mail.subject',
            :filter => filter,
            :start_date => params[:start_date].to_date, 
            :end_date => params[:end_date].to_date)
  end

  def generate_body_html(html, inline_attachments, account)
    html_part = Nokogiri::HTML(html)
    if html_part.at_css('img.inline-image')
      build_body_html_with_inline_attachments(html_part, inline_attachments, account)
    else
      html.html_safe
    end
  end

  def ticket_based_friendly_email(ticket)
    reply_email = ticket.friendly_reply_email
    reply_email.match(%r((.*)? <(.*)>)) ? "#{$1} <#{modified_reply_email($2, ticket)}>" : modified_reply_email(reply_email, ticket) 
    #regex here matches name <email>
  end

  def modified_reply_email(email, ticket)
    email.sub(%r((.*)(@.*))){"#{$1}+TKT#{ticket.display_id}#{$2}"} 
    #regex to substitute something@something.com to something+TKT123@something.com
  end

  def build_body_html_with_inline_attachments(html_part, inline_attachments, account)
    TMail::HeaderField::FNAME_TO_CLASS.delete 'content-id'
    html_part.xpath('//img[@class="inline-image"]').each do |inline|
      inline_attachment = account.attachments.find_by_id(inline['data-id'])
      if inline_attachment
        cid = ActiveSupport::SecureRandom.hex(8)
        inline_attachments.push({ :cid => cid, :attachment => inline_attachment})
        inline.set_attribute('src', "cid:#{cid}")
        inline.set_attribute('height', inline['data-height']) unless inline['data-height'].blank?
      end
    end
    return html_part.at_css("body").inner_html.html_safe
  end

  def handle_inline_attachments(inline_attachments)
    inline_attachments.each do |inline_attachment|
      attachment  :content_type => inline_attachment[:attachment].content_content_type, 
              :headers => { 'Content-ID' => "<#{inline_attachment[:cid]}>",
                            'Content-Disposition' => "inline; filename=\"#{inline_attachment[:attachment].content_file_name}\"",
                            'X-Attachment-Id' => inline_attachment[:cid] },
                  :body => File.read(inline_attachment[:attachment].content.to_file.path), 
                  :filename => inline_attachment[:attachment].content_file_name
    end   
  end
end