class Fixtures::DefaultChatTicket < Fixtures::DefaultTicket

  attr_accessor :conv_template

  def initialize
    @conv_template = build_chat_conversation
    super
  end

  def create
    create_ticket
  end

  private

    # property methods.
    def source 
      TicketConstants::SOURCE_KEYS_BY_TOKEN[:chat]
    end

    def priority
      TicketConstants::PRIORITY_KEYS_BY_TOKEN[:medium]
    end

    def type
      I18n.t('problem')
    end

    def meta_data
      Helpdesk::DEFAULT_TICKET_PROPERTIES[:chat_ticket][:meta]
    end

    def description_html
      @description_html ||= chat_conversation + I18n.t(:"default.ticket.#{source_name}.body_footer", :onclick => "inline_manual_player.activateTopic(19417);")
    end

    def created_at
      account.created_at
    end

    #methods
    def build_chat_conversation
      template = ''
      chat_conversation = I18n.t(:'default.ticket.chat.conversation')

      (1..11).each do |conv_index|
        data_hash = {}
        conv_type = (chat_conversation[:requester].key?(:"#{conv_index}") ? "requester".to_sym : "agent".to_sym)
        msg = chat_conversation[conv_type][:"#{conv_index}"]
        data_hash = (conv_type == :requester ? { photo_url: '/images/fillers/profile_blank_thumb.gif', background_color: 'rgba(255,255,255,0.5)'} : { photo_url: '/images/misc/profile_blank_thumb.jpg', background_color: 'rgba(242,242,242,0.3)'})
        data_hash.merge!({ name: safe_send(conv_type.to_s).name, msg: msg })
        template += template(data_hash)
      end
      template
    end

    def chat_conversation
      return "<div class='conversation_wrap' style='padding-top:0'><div style='padding:10px 0 10px 10px'>" + 
        I18n.t(:'default.ticket.chat.end_note', :requester => requester.name, :agent => agent.name) + 
        "<br></div><table style='width:100%; font-size:12px; border-spacing:0px; border-collapse: collapse; margin:0; border-right:0;  border-bottom:0'>" + 
        conv_template + "</table></div>"
    end

    def template(data_hash)
      return "<tr style='vertical-align:top; border-top: 1px solid #eee;" + "background: #{data_hash[:background_color]} '>" +
        "<td style='padding:10px; width:50px; border:0'>" +
        "<img src=\'#{data_hash[:photo_url]}\' style='border-radius: 4px; width: 30px; float: left; border: 1px solid #eaeaea; max-width:inherit' alt='' />"+
        "</td>" +
        "<td style='padding:10px 0; width: 80%; border:0'> <b style='color:#666;'>#{data_hash[:name]}</b>" +
        "<p style='margin:2px 0 0 0; line-height:18px; color:#777;'>#{data_hash[:msg]}</p>" +
        "</td>" +
        "<td>&nbsp;</td>" +
        "</tr>"
    end
end
