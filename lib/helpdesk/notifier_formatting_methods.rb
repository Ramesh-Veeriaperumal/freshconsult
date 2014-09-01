module Helpdesk::NotifierFormattingMethods

  def formatted_subject(ticket)
    "Re: #{encoded_ticket_id(ticket)} #{ticket.subject}"
  end

  def fwd_formatted_subject(ticket)
    "Fwd: #{encoded_ticket_id(ticket)} #{ticket.subject}"
  end

  def generate_body_html(html, inline_attachments, account)
    html_part = Nokogiri::HTML(html)
    if html_part.at_css('img.inline-image')
      build_body_html_with_inline_attachments(html_part, inline_attachments, account)
    else
      html.html_safe
    end
  end

  def encoded_ticket_id ticket
    ticket.encode_display_id unless ticket.account.features?(:id_less_tickets)
  end

  def generate_email_references(ticket)
    references = (ticket.header_info && ticket.header_info[:message_ids]) ? "<#{ticket.header_info[:message_ids].join(">,<")}>" : ""
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