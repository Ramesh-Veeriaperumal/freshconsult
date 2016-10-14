module Concerns::TicketsViewConcern
  extend ActiveSupport::Concern

  private
    def bind_last_reply(item, signature, forward = false, quoted = false, remove_cursor = false)
      # last_conv = (item.is_a? Helpdesk::Note) ? item :
                  # ((!forward && ticket.notes.visible.public.last) ? ticket.notes.visible.public.last : item)

      draft_hash = get_tickets_redis_hash_key(draft_key)
      draft_message = draft_hash ? draft_hash["draft_data"] : ""

      if(remove_cursor)
        unless draft_message.blank?
          nokigiri_html = Nokogiri::HTML(draft_message)
          nokigiri_html.css('[rel="cursor"]').remove
          draft_message = nokigiri_html.at_css("body").inner_html.to_s
        end
      end

      return ( draft_message || bind_last_conv(item, signature, false, quoted) )
    end

    def bind_last_conv(item, signature, forward = false, quoted = true)
      ticket = (item.is_a? Helpdesk::Ticket) ? item : item.notable
      default_reply = (signature.blank?)? "<p/><p/><br/>": "<p/><p><br></br></p><p></p><p></p>
  <div>#{signature}</div>"
      quoted_text = ""

      if quoted or forward
        quoted_text = quoted_text(item, forward)
      else
        default_reply = parsed_reply_template(ticket, signature)
      end

      "#{default_reply} #{quoted_text}"
    end

    def parsed_reply_template(ticket, signature)
      # Adding <p> tag for the IE9 text not shown issue
      # default_reply = (signature.blank?)? "<p/><br/>": "<p/><div>#{signature}</div>"

      requester_template = current_account.email_notifications.find_by_notification_type(EmailNotification::DEFAULT_REPLY_TEMPLATE).get_reply_template(ticket.requester)
      if(!requester_template.nil?)
        requester_template.gsub!('{{ticket.satisfaction_survey}}', '')
        reply_email_template = Liquid::Template.parse(requester_template).render('ticket' => ticket,'helpdesk_name' => ticket.account.portal_name)
        # Adding <p> tag for the IE9 text not shown issue
        default_reply = (signature.blank?)? "<p/><div>#{reply_email_template}</div>" : "<p/><div>#{reply_email_template}<br/>#{signature}</div>"
      end

      default_reply
    end

    def quoted_text(item, forward = false)
      # item can be note/ticket
      # If its a ticket we will be getting the last note from the ticket
      @last_item = (item.is_a?(Helpdesk::Note) or forward) ? item : (item.notes.visible.public.last || item)

      %(<div class="freshdesk_quote">
          <blockquote class="freshdesk_quote">#{I18n.t('ticket.quoted_text.wrote_on')} #{formated_date(@last_item.created_at)}
            <span class="separator" />, #{user_details_template(@last_item)} #{I18n.t('ticket.quoted_text.wrote')}:
            #{ (@last_item.description_html || extract_quote_from_note(@last_item).to_s)}
          </blockquote>
         </div>)
    end

    def user_details_template(item)
      user = (item.is_a? Helpdesk::Ticket) ? item.requester :
              ((item.user.customer?) ? item.user :
                { "name" => item.notable.reply_name, "email" => item.notable.reply_email })

      %( #{h(user['name'])} &lt;#{h(user['email'])}&gt; )
    end

    def extract_quote_from_note(note)
      unless note.full_text_html.blank?
        doc = Nokogiri::HTML(note.full_text_html)
        doc_fd_css = doc.css('div.freshdesk_quote')
        unless doc_fd_css.blank?
          # will show last 4 conversations apart from recent one
          remove_prev_quote = doc_fd_css.xpath('//div/child::*[1][name()="blockquote"]')[3]
          remove_prev_quote.remove unless remove_prev_quote.blank?
        end
        doc.at_css("body").inner_html
      end
    end
end