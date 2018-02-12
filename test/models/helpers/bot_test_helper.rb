module BotTestHelper

  def create_portal(params = {})
    test_portal = FactoryGirl.build(:portal,
      name: params[:portal_name] || Faker::Name.name,
      portal_url: params[:portal_url] || '',
      language: 'en',
      forum_category_ids: (params[:forum_category_ids] || ['']),
      solution_category_metum_ids: (params[:solution_category_metum_ids] || params[:solution_category_ids] || ['']),
      account_id: @account.id,
      preferences: {
        logo_link: '',
        contact_info: '',
        header_color: '#252525',
        tab_color: '#006063',
        bg_color: '#efefef'
      })
    test_portal.save(validate: false)
    test_portal
  end

  def add_new_bot
    portal = create_portal
    Account.current.bots.where(portal_id: portal.id).first || create_bot(portal)
  end

  def create_bot(portal)
    bot = FactoryGirl.build(:bot,
                            account_id: Account.current.id,
                            portal_id: portal.id,
                            last_updated_by: get_admin.id,
                            enable_in_portal: true,
                            external_id: UUIDTools::UUID.timestamp_create.hexdigest)
    bot.save
    bot.category_ids = portal.solution_category_metum_ids
    bot
  end

  def central_publish_ml_training_start_pattern(bot)
    {
      external_id: bot.external_id,
      category_ids: bot.solution_category_metum_ids,
      account_id: bot.account_id
    }
  end

  def central_publish_ml_training_end_pattern(bot)
    {
      external_id: bot.external_id,
      category_ids: bot.solution_category_metum_ids,
      account_id: bot.account_id,
      training_completed: bot.training_completed
    }
  end
end
