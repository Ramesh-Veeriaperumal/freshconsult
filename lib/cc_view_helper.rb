class CcViewHelper

	include ParserUtil

  def initialize source, cc_emails, dropped_cc_emails
    @source             = source
    @cc_emails          = cc_emails
    @dropped_cc_emails  = dropped_cc_emails
  end

  def cc_content
    html = ""
    if @cc_emails.present? || @dropped_cc_emails.present?
      html << "<span class='ellipsis clearfix #{cc_class}' rel='hover-popover' data-html = 'true'  data-placement = 'bottom' data-content = \"<div class='email-details'>#{popover_details.to_s}</div>\"> Cc: "
      html << (@cc_emails.present? ? inline_email_strings(@cc_emails) : "")
      html << (@dropped_cc_emails.present? ? inline_striked_email_strings(@dropped_cc_emails) : "")
      html << "</span>"      
    end
    html.html_safe
  end

  def cc_agent_inline_content 
    inline_email_strings(@cc_emails) + inline_striked_email_strings(@dropped_cc_emails) 
  end

  def cc_agent_hover_content
    form_email_strings(@cc_emails) + form_striked_email_strings(@dropped_cc_emails)
  end

  private

    def inline_email_strings emails
      emails.present? ? parse_to_comma_sep_emails(emails)+trailing_comma : ""
    end

    def inline_striked_email_strings emails
      emails.present? ? "<span>#{parse_to_comma_sep_dropped_emails(emails)}</span>" : ""
    end  

    def form_email_strings emails
      emails.present? ? parse_to_comma_sep_emails(emails).split(",").join(",<br>")+trailing_comma : ""
    end

    def form_striked_email_portal_strings emails
      emails.present? ? "<p data-toggle='tooltip' data-original-title='#{I18n.t('dropped_due_to_moderation')}'>#{hover_dropped_emails(emails)}</p>": ""
    end

    def form_striked_email_strings emails
      emails.present? ? "<br /><span class='tooltip' title='#{I18n.t('dropped_due_to_moderation')}'>#{hover_dropped_emails(emails)}</span>": ""
    end

    def popover_details
      return "" if @cc_emails.blank? && @dropped_cc_emails.blank?
      cc_emails_string = @cc_emails.present? ? form_email_strings(@cc_emails) : ""
      cc_emails_string << form_striked_email_portal_strings(@dropped_cc_emails) if @dropped_cc_emails.present?
      cc_array = []
      cc_array << [I18n.t('helpdesk.shared.cc'), cc_emails_string] if cc_emails_string.present?
      cc_array.map{|c| "<span class='emailcc info-text'>#{c.first} : </span><span class='emaillist'>#{c.last}</span>"}.join
    end

    def cc_class
      @source.is_a?(Helpdesk::Ticket) ? "ticket_cc" : "note_cc"
    end

    def trailing_comma
      @dropped_cc_emails.present? ? ", " : ""
    end

    def parse_to_comma_sep_dropped_emails emails
      emails.map { |email| "<del>#{parse_email_text(email)[:email]}</del>" }.join(", ")
    end

    def hover_dropped_emails emails
      parse_to_comma_sep_dropped_emails(emails).split(",").join(",<br>")
    end

end