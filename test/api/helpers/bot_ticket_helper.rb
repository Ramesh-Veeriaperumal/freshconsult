module BotTicketHelper
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

  def create_bot(portal_id)
    bot = FactoryGirl.build(:bot,
                            account_id: Account.current.id,
                            portal_id: portal_id,
                            last_updated_by: get_admin.id,
                            template_data: test_template_data,
                            enable_in_portal: true,
                            external_id: generate_uuid,
                            additional_settings: {
                              bot_hash: generate_uuid,
                              is_default: false
                            })
    bot.save
    bot
  end

  def generate_uuid
    UUIDTools::UUID.timestamp_create.hexdigest
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

  def test_template_data
    test_template_data = {
      header: Faker::Lorem.sentence,
      theme_colour: '#039a7b',
      widget_size: 'STANDARD'
    }
  end
end
