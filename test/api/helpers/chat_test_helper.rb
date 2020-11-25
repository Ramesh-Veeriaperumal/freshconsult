module ChatTestHelper
  include ProductsHelper

  def create_chat_widget(site_id: 1, associate_product: false, widget_id: 1, active: true)
    chat_setting = Account.current.chat_setting
    chat_setting.site_id = site_id
    chat_setting.save
    product = create_product if associate_product
    chat_widget = Account.current.chat_widgets.new(
      product_id: product.try(:id),
      widget_id: widget_id,
      chat_setting_id: chat_setting.id,
      active: active,
      portal_login_required: false,
      main_widget: 1
    )
    chat_widget.save
    chat_widget
  end

  def clear_chat_widget_settings(widget)
    widget.chat_setting.try(:destroy)
    widget.destroy
  end

  def create_ticket_params(widget_id: nil, content: nil, agent_id: nil, group_id: nil, email: 'sam@fujairah.gov.ae')
    {
      ticket: {
        email: email,
        name: 'DEPT. OF IND. &amp; ECONOMY GOVT. OF FUJAIRAH',
        phone: '14370557',
        subject: 'hat with DEPT. OF IND. &amp; ECONOMY GOVT. OF FUJAIRAH on Thu',
        widget_id: widget_id,
        content: content || "<div class='conversation_wrap' style='padding-top:0'><div style='padding:10px 0 10px 10px'>\n       Created via Chat. Conversation between <b>DEPT. OF IND. &amp; ECONOMY GOVT. OF FUJAIRAH",
        meta: {
          referrer: nil,
          user_agent: 'Chrome/84.0.4147 (Windows 10.0.0)',
          ip_address: nil,
          location: nil,
          visitor_os: 'Windows 10.0.0'
        },
        agent_id: agent_id,
        group_id: group_id
      },
      chat: {
        ticket: {
          email: 'sam@fujairah.gov.ae',
          name: 'DEPT. OF IND. &amp; ECONOMY GOVT. OF FUJAIRAH',
          phone: '14370557',
          subject: 'hat with DEPT. OF IND. &amp; ECONOMY GOVT. OF FUJAIRAH on Thu',
          widget_id: widget_id,
          content: content || "<div class='conversation_wrap' style='padding-top:0'><div style='padding:10px 0 10px 10px'>\n       Created via Chat. Conversation between <b>DEPT. OF IND. &amp; ECONOMY GOVT. OF FUJAIRAH",
          meta: {
            referrer: nil,
            user_agent: 'Chrome/84.0.4147 (Windows 10.0.0)',
            ip_address: nil,
            location: nil,
            visitor_os: 'Windows 10.0.0'
          },
          agent_id: agent_id,
          group_id: group_id
        }
      }
    }
  end

  def trigger_params(account_id: Account.current.id, is_empty_token: false, widget_id: 1, event_type: '', content_as_json: false, chat_type: 'offline', group_id: nil, empty_site: false, ticket_id: nil, add_message: true)
    site_id = 'a507c51cd62e2167b14d589e791b5132' unless empty_site
    token = Digest::SHA512.hexdigest("#{ChatConfig['secret_key']}::#{site_id}") unless is_empty_token
    {
      content: content_data(content_as_json, widget_id, chat_type, group_id, ticket_id, add_message),
      eventType: event_type,
      token: token,
      site_id: 'a507c51cd62e2167b14d589e791b5132',
      account_id: account_id
    }
  end

  def content_data(as_json, widget_id, chat_type, group_id, ticket_id, add_message)
    content = {
      site_id: 'a507c51cd62e2167b14d589e791b5132',
      messages: [
        {
          siteId: 'a507c51cd62e2167b14d589e791b5132',
          username: 'subhodip panda',
          msg: 'please respond to my ticket issues',
          userId: 'visitor800113971648',
          type: 1,
          chatId: '0c0fcf26-0d70-423d-929d-e6e2fd38ee88',
          createdAt: '1605162186513',
          updatedAt: '1605162186513',
          name: 'subhodip panda',
          id: 'c6e550b8-c0f7-4107-8709-9682922a1e68',
          actualCreatedAt: nil
        }
      ],
      email: 'panda.subhodip@gmail.com',
      name: 'subhodip panda',
      widget_id: widget_id,
      type: chat_type,
      group_id: group_id,
      ticket_id: ticket_id
    }
    content.delete(:messages) unless add_message
    as_json ? content.to_json : content
  end

  def create_shortcode_params
    {
      attributes: {
        code: '[FILTERED]',
        message: 'Hi'
      },
      method: :post,
      action: 'create_shortcode'
    }
  end

  def delete_shortcode_params(id)
    {
      action: 'delete_shortcode',
      method: :delete,
      id: id
    }
  end

  def update_shortcode_params(id)
    {
      action: 'update_shortcode',
      attributes: {
        code: '[FILTERED]',
        message: 'Thanks for reaching out! For online purchases,
        we can only allow for one discount code at a time per transaction. '
      },
      method: :put,
      id: id
    }
  end

  def update_availability_params(id)
    {
      action: 'update_availability',
      status: false,
      method: :put,
      id: id,
      chat: {
        status: false
      }
    }
  end

  def export_params
    {
      filters: {
        widgetId: '0',
        actualRange: '01 Jan, 2017-06 Nov, 2020',
        frm: '01 Jan, 2017 00:00:00 GMT',
        to: 'Fri, 06 Nov 2020 08:30:01 GMT',
        agentId: '0',
        type: '0',
        sort: 'desc'
      },
      format: 'csv'
    }
  end

  def download_export_params
    {
      token: 'EXPORTTOKEN'
    }
  end

  def toggle_params(active = false)
    {
      attributes: {
        active: active
      }
    }
  end

  def update_site_params(cobrowsing = 'false')
    {
      attributes: {
        cobrowsing: cobrowsing
      }
    }
  end

  def get_groups_params(id)
    {
      widget_id: id
    }
  end

  def visitor_params(type = 'newVisitor')
    {
      type: type
    }
  end
end
