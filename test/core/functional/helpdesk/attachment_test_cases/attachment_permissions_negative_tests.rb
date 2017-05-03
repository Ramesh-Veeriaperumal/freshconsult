module AttachmentPermissionsNegativeTests

  def test_restricted_agent_cant_view_other_ticket_attachments
    restricted_agent = add_agent(@account, {:ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]})
    create_ticket_with_attachments
    ticket = Helpdesk::Ticket.last
    log_in(restricted_agent)
    attachment = ticket.attachments.first
    xhr :get, :show, {:id => attachment.id}
    assert_response :success
    assert_equal flash[:notice], "You are not allowed to access this page!"
  end


  def test_contact_cant_view_other_ticket_attachments
    user = add_new_user(@account)
    create_ticket_with_attachments
    ticket = Helpdesk::Ticket.last
    log_in(user)
    attachment = ticket.attachments.first
    xhr :get, :show, {:id => attachment.id}
    assert_response :success
    assert_equal flash[:notice], "You are not allowed to access this page!"
  end

  def test_restricted_ticket_agent_cant_delete_other_ticket_attachments
    restricted_agent = add_agent(@account, {:ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]})
    create_ticket_with_attachments
    ticket = Helpdesk::Ticket.last
    log_in(restricted_agent)
    attachment = ticket.attachments.first
    xhr :delete, :destroy, {:id => attachment.id}
    assert_redirected_to send(Helpdesk::ACCESS_DENIED_ROUTE)
  end

  def test_contact_cant_delete_other_ticket_attachments
    user = add_new_user(@account)
    create_ticket_with_attachments
    ticket = Helpdesk::Ticket.last
    log_in(user)
    attachment = ticket.attachments.first
    xhr :delete, :destroy, {:id => attachment.id}
    assert_redirected_to send(Helpdesk::ACCESS_DENIED_ROUTE)
  end

  def test_restricted_agent_cant_view_other_note_attachments
    agent = add_agent(@account, {:ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]})
    create_ticket
    ticket = Helpdesk::Ticket.last
    create_note_with_attachments({:ticket_id => ticket.id, :user_id => get_admin.id})
    note = Helpdesk::Note.last
    log_in(agent)
    attachment = note.attachments.first
    xhr :get, :show, {:id => attachment.id}
    assert_response :success
    assert_equal flash[:notice], "You are not allowed to access this page!"
  end

  def test_contact_cant_view_other_note_attachments
    user = add_new_user(@account)
    create_ticket
    ticket = Helpdesk::Ticket.last
    create_note_with_attachments({:ticket_id => ticket.id, :user_id => get_admin.id})
    note = Helpdesk::Note.last
    log_in(user)
    attachment = note.attachments.first
    xhr :get, :show, {:id => attachment.id}
    assert_response :success
    assert_equal flash[:notice], "You are not allowed to access this page!"
  end

  def test_contact_cant_view_private_note_attachments
    user = add_new_user(@account)
    log_in(user)
    create_ticket({:requester_id => user.id})
    ticket = Helpdesk::Ticket.last
    create_note_with_attachments({:ticket_id => ticket.id, :private => true, :user_id => get_admin.id})
    note = Helpdesk::Note.last
    attachment = note.attachments.first
    xhr :get, :show, {:id => attachment.id}
    assert_response :success
    assert_equal flash[:notice], "You are not allowed to access this page!"
  end

  def test_restricted_agent_cant_delete_other_ticket_notes_attachments
    agent = add_agent(@account, {:ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]})
    user = add_new_user(@account)
    create_ticket(:requester_id => user.id)
    ticket = Helpdesk::Ticket.last
    create_note_with_attachments({:ticket_id => ticket.id, :user_id => user.id})
    note = Helpdesk::Note.last
    log_in(agent)
    attachment = note.attachments.first
    xhr :delete, :destroy, {:id => attachment.id}
    assert_redirected_to send(Helpdesk::ACCESS_DENIED_ROUTE)
  end

  def test_contact_cant_delete_others_note_attachments
    user = add_new_user(@account)
    log_in(user)
    create_ticket(:requester_id => user.id)
    ticket = Helpdesk::Ticket.last
    create_note_with_attachments({:ticket_id => ticket.id, :user_id => get_admin.id})
    note = Helpdesk::Note.last
    attachment = note.attachments.first
    xhr :delete, :destroy, {:id => attachment.id}
    assert_redirected_to send(Helpdesk::ACCESS_DENIED_ROUTE)
  end

  def test_anonymous_users_cant_view_user_forum_attachments
    user = add_new_user(@account, :company_id => create_company.id)
    forum = create_test_forum(create_test_category, 1, Forum::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
    topic = create_test_topic_with_attachments(forum, user)
    attachment = topic.posts.last.attachments.first
    log_out
    xhr :get, :show, {:id => attachment.id}
    assert_response :success
    assert_equal flash[:notice], "You must be logged in to access this page" 
  end

  def test_other_users_cant_view_company_forum_attachments
    @agent = add_agent(@account, {:ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]})
    company = create_company
    user = add_new_user(@account)
    forum = create_test_forum(create_test_category, 1, Forum::VISIBILITY_KEYS_BY_TOKEN[:company_users])
    forum.customer_forums.create(:customer_id => company.id)
    topic = create_test_topic_with_attachments(forum, @agent)
    log_in(user)
    attachment = topic.posts.last.attachments.first
    xhr :get, :show, {:id => attachment.id}
    assert_response :success
    assert_equal flash[:notice], "You are not allowed to access this page!" 
  end

  def test_users_cant_delete_others_post_attachments
    @agent = add_agent(@account, {:ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]})
    user = add_new_user(@account)
    forum = create_test_forum(create_test_category)
    topic = create_test_topic_with_attachments(forum, @agent)
    log_in(user)
    attachment = topic.posts.last.attachments.first
    xhr :delete, :destroy, {:id => attachment.id}
    assert_redirected_to send(Helpdesk::ACCESS_DENIED_ROUTE)
  end

  def test_anonymous_users_cant_view_users_article_attachments
    @agent = add_agent(@account, {:ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]})
    folder = create_folder(:visibility => Solution::FolderMeta::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
    article_meta = create_article(:folder_id => folder.id,
      :attachments => [{:resource => File.new(Rails.root.join("spec/fixtures/files/attachment.txt"))}] )
    log_out
    attachment = article_meta.solution_articles.first.attachments.first    
    xhr :get, :show, {:id => attachment.id}
    assert_response :success
    assert_equal flash[:notice], "You must be logged in to access this page" 
  end

  def test_other_users_cant_view_company_article_attachments
    company = create_company
    user = add_new_user(@account)
    @agent = add_agent(@account, {:ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]})
    folder = create_folder
    folder.add_visibility(Solution::FolderMeta::VISIBILITY_KEYS_BY_TOKEN[:company_users], [company.id], false)
    article_meta = create_article(:folder_id => folder.id,
       :attachments => [{:resource => File.new(Rails.root.join("spec/fixtures/files/attachment.txt"))}] )
    attachment = article_meta.solution_articles.first.attachments.first
    log_in(user)
    xhr :get, :show, {:id => attachment.id}
    assert_response :success
    assert_equal flash[:notice], "You are not allowed to access this page!" 
  end

  def test_users_cant_view_draft_article_attachments
    user = add_new_user(@account)
    @agent = add_agent(@account, {:ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]})
    folder = create_folder
    article_meta = create_article(:folder_id => folder.id, :status => Solution::Article::STATUS_KEYS_BY_TOKEN[:draft],
       :attachments => [{:resource => File.new(Rails.root.join("spec/fixtures/files/attachment.txt"))}] )
    attachment = article_meta.solution_articles.first.attachments.first
    log_in(user)
    xhr :get, :show, {:id => attachment.id}
    assert_response :success
    assert_equal flash[:notice], "You are not allowed to access this page!" 
  end

  def test_agents_cant_view_others_draft_attachments
    agent1 = add_agent(@account)
    agent2 = add_agent(@account, {:ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]})
    add_user_draft_attachments(:user_id => agent2.id)
    log_in(agent1)
    attachment = Helpdesk::Attachment.last
    xhr :get, :show, {:id => attachment.id}
    assert_response :success
    assert_equal flash[:notice], "You are not allowed to access this page!" 
  end

  def test_agents_cant_delete_others_draft_attachments
    agent1 = add_agent(@account)
    agent2 = add_agent(@account, {:ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]})
    add_user_draft_attachments(:user_id => agent2.id)
    log_in(agent1)
    attachment = Helpdesk::Attachment.last
    xhr :delete, :destroy, {:id => attachment.id}
    assert_redirected_to send(Helpdesk::ACCESS_DENIED_ROUTE)
  end

end