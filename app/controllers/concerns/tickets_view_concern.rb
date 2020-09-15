module Concerns
  module TicketsViewConcern
    extend ActiveSupport::Concern

    private

      def bind_last_reply(item, signature, forward = false, quoted = false, remove_cursor = false, mobile_request = false)
        # last_conv = (item.is_a? Helpdesk::Note) ? item : ((!forward && ticket.notes.visible.public.last) ? ticket.notes.visible.public.last : item)

        draft_hash = @ticket.draft
        draft_message = draft_hash.exists? ? draft_hash.body : ''

        if remove_cursor
          unless draft_message.blank?
            nokigiri_html = Nokogiri::HTML(draft_message)
            nokigiri_html.css('[rel="cursor"]').remove
            draft_message = nokigiri_html.at_css('body').inner_html.to_s
          end
        end

        draft_message || bind_last_conv(item, signature, forward, quoted, mobile_request)
      end

      def bind_last_conv(item, signature, forward = false, quoted = true, mobile_request = false)
        ticket = (item.is_a? Helpdesk::Ticket) ? item : item.notable
        if mobile_request
          default_reply_forward = (signature.blank?)? "<p/><p/><br/>": "<br/><div>#{signature}</div>"
        else
          default_reply_forward = signature.blank? ? '<p/><p/><br/>' : "<p/><p><br></br></p><p></p><p></p><div>#{signature}</div>"
        end
        ticket.escape_liquid_attributes = true
        quoted_text = ''
        if quoted
          quoted_text = quoted_text(item, forward)
        elsif forward
          default_reply_forward = parsed_forward_template(ticket, signature)
        else
          default_reply_forward = parsed_reply_template(ticket, signature)
        end
        "#{default_reply_forward} #{quoted_text}"
      end

      def parsed_reply_template(ticket, signature)
        # Adding <p> tag for the IE9 text not shown issue
        # default_reply = (signature.blank?)? "<p/><br/>": "<p/><div>#{signature}</div>"

        requester_template = current_account.email_notifications.find_by_notification_type(EmailNotification::DEFAULT_REPLY_TEMPLATE).get_reply_template(ticket.requester)
        unless requester_template.nil?
          requester_template.gsub!('{{ticket.satisfaction_survey}}', '')
          reply_email_template = Liquid::Template.parse(requester_template).render('ticket' => ticket, 'helpdesk_name' => ticket.account.helpdesk_name)
          # Adding <p> tag for the IE9 text not shown issue
          default_reply = signature.blank? ? "<p/><div>#{reply_email_template}</div>" : "<p/><div>#{reply_email_template}<br/>#{signature}</div>"
        end

        default_reply
      end

      def parsed_forward_template(ticket, signature)
        # Adding <p> tag for the IE9 text not shown issue
        # default_reply = (signature.blank?)? "<p/><br/>": "<p/><div>#{signature}</div>"

        if current_account.email_notifications.find_by_notification_type(EmailNotification::DEFAULT_FORWARD_TEMPLATE).present?
          requester_template = current_account.email_notifications.find_by_notification_type(EmailNotification::DEFAULT_FORWARD_TEMPLATE).get_forward_template(ticket.requester)
          if requester_template.present?
            requester_template.gsub!('{{ticket.satisfaction_survey}}', '')
            forward_email_template = Liquid::Template.parse(requester_template).render('ticket' => ticket, 'helpdesk_name' => ticket.account.helpdesk_name)
            # Adding <p> tag for the IE9 text not shown issue
            default_forward = signature.blank? ? "<p/><div>#{forward_email_template}</div>" : "<p/><div>#{forward_email_template}<br/>#{signature}</div>"
          end
        else
          default_forward = signature.blank? ? '<p/>' : "<p/><p><br></br></p><p></p><p></p><div>#{signature}</div>"
        end

        default_forward
      end

      def quoted_text(item, forward = false)
        # item can be note/ticket
        # If its a ticket we will be getting the last note from the ticket
        @last_item = item.is_a?(Helpdesk::Note) || forward ? item : (item.notes.visible.public_notes.last || item)
        item_requester = item.is_a?(Helpdesk::Ticket) ? item.requester : item.notable.requester
        quoted_text_language = (item_requester.try(:language) || Account.current.language).to_sym
        # Setting I18n.locale to requester's language as the date_time in the quoted_text must be of requester's language (Eg: On Wed, 20 May at 5:10 AM)
        if I18n.locale != quoted_text_language
          old_i18n = I18n.locale
          I18n.locale = quoted_text_language
        end
        quoted_text = %(<div class="freshdesk_quote">
                          <blockquote class="freshdesk_quote">
                            #{I18n.t('ticket.quoted_text.wrote_on')}
                            #{formated_date(@last_item.created_at.in_time_zone((item_requester || User.current || Account.current).time_zone))}
                            <span class="separator" />, #{user_details_template(@last_item)} #{I18n.t('ticket.quoted_text.wrote')}:
                            #{(@last_item.description_html || extract_quote_from_note(@last_item).to_s)}
                          </blockquote>
                        </div>)
        # Resetting I18n.locale to the old value.
        I18n.locale = old_i18n if old_i18n.present?
        quoted_text
      end

      def user_details_template(item)
        if (item.is_a? Helpdesk::Ticket)
          if item.source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:outbound_email]
            user = { "name" => item.reply_name, "email" => item.reply_email }
          else
            user = item.requester
          end
        else
          user = user_details_for_note item
        end

        %( #{h(user['name'])} &lt;#{h(user['email'])}&gt; )
      end

      def user_details_for_note item
        prev_note_sender = parse_email item.from_email
        if prev_note_sender[:email] && item.account.support_emails_in_downcase.include?(prev_note_sender[:email].downcase)
          user = { "name" => prev_note_sender[:name], "email" => prev_note_sender[:email] }
        elsif item.user.customer?
          user = item.user
        else
          user = { "name" => item.notable.reply_name, "email" => item.notable.reply_email }
        end
        user
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
          doc.at_css('body').inner_html
        end
      end

      def reply_cc_emails(ticket)
        ticket.notes.visible.public_notes.exists? ? ticket.current_cc_emails : ticket.reply_to_all_emails
      end
  end
end
