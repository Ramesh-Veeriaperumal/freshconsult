module ShopifyTestHelper

  def sample_shopify_create_ticket_command(account, context, options = {})
    context = get_command_context_shopify(context, options)
    data = {
      "subject": options[:subject] || 'Sample Subject',
      "requester_id": options[:requester_id],
      "description": options[:description],
      "source": 10,
      "status": 5,
      "created_at": options[:created_at] || '2015-07-09T13:08:06Z'
    }
    shopify_data = sample_shopify_data
    options = {
      owner: 'proactive',
      client: 'helpkit',
      pod: ChannelFrameworkConfig['pod'],
      command_name: 'create_ticket'
    }

    channel_payload_shopify('helpkit_command', account, options, context, data, shopify_data)
  end

  def get_command_context_shopify(context, options = {})
    {
      "from": context
    }
  end

  def sample_shopify_data
    {
      "total_price": '300.00',
      "email": "rajesh.krishnan@test.com",
      "fulfillment_status": "fulfilled",
      "customer": {
        "first_name": "Rajesh",
        "email"=> "rajesh.krishnan@test.com",
        "last_name": "Krishnan",
        "phone": "1231231231"
      },
      "line_items": "One plus 5 back cover, One plus 6 back cover"
    }
  end

  def channel_payload_shopify(type, account, options, context, data, shopify_data)
    {
      "msg_id": SecureRandom.uuid,
      "payload_type": type,
      "account_id": account.id,
      "payload": {
        "owner": options[:owner],
        "client": options[:client],
        "account_id": account.id,
        "domain": "https://#{account.full_domain}",
        "pod": options[:pod],
        "context": context,
        "data": data,
        "shopify": shopify_data,
        "meta": {
          "fallbackToReplyQueue": false,
          "timeout": 30_000,
          "waitForReply": false
        },
        "command_name": options[:command_name],
        "command_id": SecureRandom.uuid,
        "schema_version": 1
      }
    }
  end

end
