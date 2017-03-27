module AttachmentPermissionsTests

  def test_restricted_ticket_agent_can_view_ticket_attachments
    restricted_agent = add_agent(@account, {:ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]})
    create_ticket_with_attachments({:responder_id => restricted_agent.id})
    ticket = Helpdesk::Ticket.last
    log_in(restricted_agent)
    attachment = ticket.attachments.first
    xhr :get, :show, {:id => attachment.id}
    assert_response :redirect
    assert_match Regexp.new(Helpdesk::Attachment.s3_path(attachment.id, "attachment.txt")), @response.redirect_url
  end

  def test_ticket_requester_can_view_ticket_attachments
    user = add_new_user(@account)
    create_ticket_with_attachments({:requester_id => user.id})
    ticket = Helpdesk::Ticket.last
    log_in(user)
    attachment = ticket.attachments.first
    xhr :get, :show, {:id => attachment.id}
    assert_response :redirect
    assert_match Regexp.new(Helpdesk::Attachment.s3_path(attachment.id, "attachment.txt")), @response.redirect_url
  end

  def test_account_admin_can_view_all_ticket_attachments
    create_ticket_with_attachments
    login_admin
    ticket = Helpdesk::Ticket.last
    attachment = ticket.attachments.first
    xhr :get, :show, {:id => attachment.id}
    assert_response :redirect
    assert_match Regexp.new(Helpdesk::Attachment.s3_path(attachment.id, "attachment.txt")), @response.redirect_url
  end

  def test_restricted_ticket_agent_can_delete_his_own_ticket_attachments
    restricted_agent = add_agent(@account, {:ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]})
    create_ticket_with_attachments({:responder_id => restricted_agent.id})
    ticket = Helpdesk::Ticket.last
    log_in(restricted_agent)
    attachment = ticket.attachments.first
    xhr :delete, :destroy, {:id => attachment.id}
    assert_response :success
  end

  def test_ticket_requester_can_delete_his_own_ticket_attachments
    user = add_new_user(@account)
    create_ticket_with_attachments({:requester_id => user.id})
    ticket = Helpdesk::Ticket.last
    log_in(user)
    attachment = ticket.attachments.first
    xhr :delete, :destroy, {:id => attachment.id}
    assert_response :success
  end

  def test_account_admin_can_delete_all_ticket_attachments
    create_ticket_with_attachments
    login_admin
    ticket = Helpdesk::Ticket.last
    attachment = ticket.attachments.first
    xhr :delete, :destroy, {:id => attachment.id}
    assert_response :success
  end

  def test_restricted_ticket_agent_can_view_note_attachments
    @agent = add_agent(@account, {:ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]})
    create_ticket({:responder_id => @agent.id})
    ticket = Helpdesk::Ticket.last
    create_note_with_attachments({:ticket_id => ticket.id})
    note = Helpdesk::Note.last
    log_in(@agent)
    attachment = note.attachments.first
    xhr :get, :show, {:id => attachment.id}
    assert_response :redirect
    assert_match Regexp.new(Helpdesk::Attachment.s3_path(attachment.id, "attachment.txt")), @response.redirect_url
  end

  def test_ticket_requester_can_view_public_note_attachments
    user = add_new_user(@account)
    log_in(user)
    create_ticket({:requester_id => user.id})
    ticket = Helpdesk::Ticket.last
    create_note_with_attachments({:ticket_id => ticket.id, :user_id => user.id})
    note = Helpdesk::Note.last
    attachment = note.attachments.first
    xhr :get, :show, {:id => attachment.id}
    assert_response :redirect
    assert_match Regexp.new(Helpdesk::Attachment.s3_path(attachment.id, "attachment.txt")), @response.redirect_url
  end

  def test_account_admin_can_view_all_note_attachments
    login_admin
    user = add_new_user(@account)
    create_ticket
    ticket = Helpdesk::Ticket.last
    create_note_with_attachments({:ticket_id => ticket.id, :user_id => user.id})
    note = Helpdesk::Note.last
    attachment = note.attachments.first
    xhr :get, :show, {:id => attachment.id}
    assert_response :redirect
    assert_match Regexp.new(Helpdesk::Attachment.s3_path(attachment.id, "attachment.txt")), @response.redirect_url
  end

  def test_restricted_ticket_agent_can_delete_his_ticket_notes_attachments
    @agent = add_agent(@account, {:ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]})
    user = add_new_user(@account)
    create_ticket({:responder_id => @agent.id})
    ticket = Helpdesk::Ticket.last
    create_note_with_attachments({:ticket_id => ticket.id, :user_id => user.id})
    note = Helpdesk::Note.last
    log_in(@agent)
    attachment = note.attachments.first
    xhr :delete, :destroy, {:id => attachment.id}
    assert_response :success
  end

  def test_ticket_requester_can_delete_his_own_note_attachments
    user = add_new_user(@account)
    log_in(user)
    create_ticket
    ticket = Helpdesk::Ticket.last
    create_note_with_attachments({:ticket_id => ticket.id, :user_id => user.id})
    note = Helpdesk::Note.last
    attachment = note.attachments.first
    xhr :delete, :destroy, {:id => attachment.id}
    assert_response :success
  end

  def test_account_admin_can_delete_all_note_attachments
    login_admin
    user = add_new_user(@account)
    create_ticket
    ticket = Helpdesk::Ticket.last
    create_note_with_attachments({:ticket_id => ticket.id, :user_id => user.id})
    note = Helpdesk::Note.last
    attachment = note.attachments.first
    xhr :delete, :destroy, {:id => attachment.id}
    assert_response :success
  end

  def test_agent_can_view_all_forum_attachments
    @agent = add_agent(@account, {:ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]})
    user = add_new_user(@account, :company_id => create_company.id)
    forum = create_test_forum(create_test_category)
    topic = create_test_topic_with_attachments(forum, user)
    log_in(@agent)
    attachment = topic.posts.last.attachments.first
    xhr :get, :show, {:id => attachment.id}
    assert_response :redirect
    assert_match Regexp.new(Helpdesk::Attachment.s3_path(attachment.id, "attachment.txt")), @response.redirect_url
  end

  def test_anonymous_users_can_view_public_forum_attachments
    user = add_new_user(@account, :company_id => create_company.id)
    forum = create_test_forum(create_test_category)
    topic = create_test_topic_with_attachments(forum, user)
    attachment = topic.posts.last.attachments.first
    xhr :get, :show, {:id => attachment.id}
    assert_response :redirect
    assert_match Regexp.new(Helpdesk::Attachment.s3_path(attachment.id, "attachment.txt")), @response.redirect_url
  end

  def test_logged_in_user_can_view_user_forum_attachments
    @agent = add_agent(@account, {:ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]})
    user = add_new_user(@account)
    log_in(user)
    forum = create_test_forum(create_test_category)
    topic = create_test_topic_with_attachments(forum, @agent)
    attachment = topic.posts.last.attachments.first
    xhr :get, :show, {:id => attachment.id}
    assert_response :redirect
    assert_match Regexp.new(Helpdesk::Attachment.s3_path(attachment.id, "attachment.txt")), @response.redirect_url
  end

  def test_company_contacts_can_view_company_forum_attachments
    @agent = add_agent(@account, {:ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]})
    company = create_company
    user = add_new_user(@account, :customer_id => company.id)
    log_in(user)
    forum = create_test_forum(create_test_category)
    forum.customer_forums.create(:customer_id => company.id)
    topic = create_test_topic_with_attachments(forum, @agent)
    attachment = topic.posts.last.attachments.first
    xhr :get, :show, {:id => attachment.id}
    assert_response :redirect
    assert_match Regexp.new(Helpdesk::Attachment.s3_path(attachment.id, "attachment.txt")), @response.redirect_url
  end

  def test_agent_can_delete_all_forum_attachments
    @agent = add_agent(@account, {:ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]})
    forum = create_test_forum(create_test_category)
    user = add_new_user(@account)
    topic = create_test_topic_with_attachments(forum, user)
    log_in(@agent)
    attachment = topic.posts.last.attachments.first
    xhr :delete, :destroy, {:id => attachment.id}
    assert_response :success
  end

  def test_agent_can_view_all_solution_article_attachments
    agent = add_agent(@account, {:ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]})
    @agent = get_admin
    article_meta = create_article(:attachments => [{:resource => File.new(Rails.root.join("spec/fixtures/files/attachment.txt"))}])
    log_in(agent)
    attachment = article_meta.solution_articles.first.attachments.first
    xhr :get, :show, {:id => attachment.id}
    assert_response :redirect
    assert_match Regexp.new(Helpdesk::Attachment.s3_path(attachment.id, "attachment.txt")), @response.redirect_url
  end

  def test_anonymous_users_can_view_public_article_attachments
    user = add_new_user(@account, :company_id => create_company.id)
    article_meta = create_article(:user_id => user.id,
       :attachments => [{:resource => File.new(Rails.root.join("spec/fixtures/files/attachment.txt"))}] )
    attachment = article_meta.solution_articles.first.attachments.first
    xhr :get, :show, {:id => attachment.id}
    assert_response :redirect
    assert_match Regexp.new(Helpdesk::Attachment.s3_path(attachment.id, "attachment.txt")), @response.redirect_url
  end

  def test_logged_in_user_can_view_user_article_attachments
    user = add_new_user(@account)
    @agent = add_agent(@account, {:ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]})
    article_meta = create_article(:attachments => [{:resource => File.new(Rails.root.join("spec/fixtures/files/attachment.txt"))}] )
    attachment = article_meta.solution_articles.first.attachments.first
    log_in(user)
    xhr :get, :show, {:id => attachment.id}
    assert_response :redirect
    assert_match Regexp.new(Helpdesk::Attachment.s3_path(attachment.id, "attachment.txt")), @response.redirect_url
  end

  def test_company_contacts_can_view_company_article_attachments
    company = create_company
    user = add_new_user(@account, :customer_id => company.id)
    @agent = add_agent(@account, {:ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]})
    folder = create_folder
    folder.add_visibility(Solution::FolderMeta::VISIBILITY_KEYS_BY_TOKEN[:company_users], [company.id], false)
    article_meta = create_article(:folder_id => folder.id,
       :attachments => [{:resource => File.new(Rails.root.join("spec/fixtures/files/attachment.txt"))}] )
    attachment = article_meta.solution_articles.first.attachments.first
    log_in(user)
    xhr :get, :show, {:id => attachment.id}
    assert_response :redirect
    assert_match Regexp.new(Helpdesk::Attachment.s3_path(attachment.id, "attachment.txt")), @response.redirect_url
  end

  def test_agent_can_delete_all_solution_article_attachments
    @agent = add_agent(@account, {:ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]})
    user = add_new_user(@account, :company_id => create_company.id)
    article_meta = create_article(:user_id => user.id,
      :attachments => [{:resource => File.new(Rails.root.join("spec/fixtures/files/attachment.txt"))}])
    log_in(@agent)
    attachment = article_meta.solution_articles.first.attachments.first
    xhr :delete, :destroy, {:id => attachment.id}
    assert_response :success
  end

end