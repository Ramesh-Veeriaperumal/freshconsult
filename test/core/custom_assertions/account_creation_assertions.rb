module AccountCreationAssertions

  # def assert_objects_with_sidekiq_off
  #   No test cases present. This is just a reference for fixtures data creating when the sidekiq is off.
  #   @account = Account.current
  #   [ 
  #     @account.groups, @account.account_va_rules, @account.ticket_filters,
  #     @account.scoreboard_levels, @account.scoreboard_ratings, @account.quests, 
  #     @account.solution_categories, @account.solution_folder_meta,
  #     @account.forums, @account.forum_categories, @account.forum_moderators
  #   ].
  #     map { |associated_objects| assert_equal(associated_objects.count, 0)  }
    
  #   object_to_count = {}
  #   object_to_count[@account.email_notifications] = 4
  #   object_to_count[@account.contact_form.all_fields] = 7
  #   object_to_count[@account.company_form.all_fields] = 2
    
  #   object_to_count.each do |object, count|
  #     assert_equal(object.count, count)
  #   end   

  #   [Integrations::Application, Doorkeeper::Application].
  #     map {|object| assert_equal(object.where(account_id: @account.id).count, 0)}

  #     compare_company_and_contact_fields_order_with_sidekiq_off(@account)
  # end

  # def compare_company_and_contact_fields_order_with_sidekiq_off account
  #   correct_order_for_company_fields = ["name", "domains"]
  #   correct_order_for_contact_fields = ["name", "job_title", "email", "phone", "company_name", "time_zone", "language"]
  #   assert_equal(@account.company_form.all_fields.map(&:name), correct_order_for_company_fields)
  #   assert_equal(@account.contact_form.all_fields.map(&:name), correct_order_for_contact_fields)
  # end

  def assert_fixtures_data
    @account = Account.current
    counts = [3, 6, 4, 6, 6, 7, 2, 3, 4, 1, 1, 20, 13, 4, 3]

    [
      @account.groups, @account.account_va_rules, @account.ticket_filters,
      @account.scoreboard_levels, @account.scoreboard_ratings, @account.quests, 
      @account.solution_categories, @account.solution_folder_meta,
      @account.forums, @account.forum_categories, @account.forum_moderators,
      @account.email_notifications, @account.contact_form.all_fields, @account.company_form.all_fields,
      @account.solution_templates
    ].each_with_index do |objects, index|
      assert_equal(objects.count, counts[index])
    end

    compare_company_and_contact_fields_order
  end

  def compare_company_and_contact_fields_order
    correct_order_for_company_fields = ["name", "description", "note", "domains"]
    correct_order_for_contact_fields = ["name", "job_title", "email", "phone", "mobile", "twitter_id", "company_name", "address", "time_zone", "language", "tag_names", "description", "client_manager"]
    assert_equal(@account.company_form.all_fields.map(&:name), correct_order_for_company_fields)
    assert_equal(@account.contact_form.all_fields.map(&:name), correct_order_for_contact_fields)
  end

end