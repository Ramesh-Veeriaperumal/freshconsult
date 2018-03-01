module BotTicketHelper

  SUPPORT_BOT = 'frankbot'.freeze
  CONFIG = CHANNEL_API_CONFIG[SUPPORT_BOT]

  def enable_bot_feature
    Account.current.add_feature(:support_bot)
    if block_given?
      yield
      disable_bot_feature
    end
  end

  def disable_bot_feature
    Account.current.revoke_feature(:support_bot)
  end

  def sign_payload(payload = {}, expiration = CONFIG[:jwt_default_expiry])
    payload = payload.dup
    payload['exp'] = Time.now.to_i + expiration.to_i if expiration
    jwt = JWT.encode(payload, CONFIG[:jwt_secret])
    JWE.encrypt(jwt, CONFIG[:secret_key], alg: 'dir', source: SUPPORT_BOT)
  end

  def set_auth_header
    request.env['X-Channel-Auth'] = sign_payload({})
  end

  def create_bot(portal_id)
    bot = FactoryGirl.build(:bot,
                            account_id: Account.current.id,
                            portal_id: portal_id,
                            last_updated_by: get_admin.id,
                            enable_in_portal: true,
                            external_id: UUIDTools::UUID.timestamp_create.hexdigest)
    bot.save
    bot
  end

  def toggle_required_attribute(fields)
    fields.each do |field|
      field.required = !field.required
      field.save
    end
  end

  def validate_bot_ticket_data(ticket, bot_external_id, query_id, conversation_id)
    bot_id = Account.current.bots.where(external_id: bot_external_id).first.id
    bot_ticket = ticket.bot_ticket
    assert_equal bot_ticket.bot_id, bot_id
    assert_equal bot_ticket.query_id, query_id
    assert_equal bot_ticket.conversation_id, conversation_id
  end
end
