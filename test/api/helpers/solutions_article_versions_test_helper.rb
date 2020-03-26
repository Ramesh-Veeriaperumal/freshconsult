module SolutionsArticleVersionsTestHelper
  def create_version_for_article(article)
    latest_version = should_create_version(article) do
      article.title = Faker::Name.name
      article.description = Faker::Lorem.paragraph
      article.save!
    end
    latest_version
  end

  def create_draft_version_for_article(article)
    draft = article.draft.presence || article.build_draft_from_article
    draft.save
    latest_version = should_create_version(article) do
      draft = Solution::Draft.find(draft.id)
      draft.title = Faker::Name.name
      draft.description = Faker::Lorem.paragraph
      draft.save!
    end
    latest_version
  end

  def enable_article_versioning(account = Account.current)
    previous_value = account.article_versioning_enabled?
    account.add_feature(:article_versioning)
    yield
  ensure
    account.revoke_feature(:article_versioning) unless previous_value
  end

  def disable_article_versioning(account = Account.current)
    previous_value = account.article_versioning_enabled?
    account.revoke_feature(:article_versioning)
    yield
  ensure
    account.add_feature(:article_versioning) if previous_value
  end

  def get_article_with_versions(language_id = Account.current.language_object.id)
    article_with_versions = Account.current.solution_articles.where(language_id: language_id).reject { |article| article.solution_article_versions.empty? }.first
    return article_with_versions if article_with_versions
    article = Account.current.solution_articles.where(language_id: language_id).first
    10.times do
      create_draft_version_for_article(article)
    end
    article.reload
    article
  end

  def article_verion_index_pattern(article_versions)
    pattern = []
    article_versions.each do |article_version|
      pattern_hash = {
        id: article_version.version_no,
        created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
        updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
        user_id: article_version.user_id,
        status: article_version.status
      }

      if article_version.status == Solution::Article::STATUS_KEYS_BY_TOKEN[:discarded]
        pattern_hash[:discarded_by] = article_version.discarded_by
      elsif article_version.status == Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
        pattern_hash[:live] = article_version.live
      end
      pattern << pattern_hash
    end
    pattern
  end

  def article_verion_pattern(article_version)
    pattern = {
      id: article_version.version_no,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      user_id: article_version.user_id,
      status: article_version.status,
      title: article_version.title,
      description: article_version.description,
      published_by: article_version.published_by,
      attachments: attachments_hash(article_version),
      cloud_files: cloud_files_hash(article_version)
    }

    if article_version.discarded?
      pattern[:discarded_by] = article_version.discarded_by
    elsif article_version.published?
      pattern[:live] = article_version.live
    elsif article_version.meta[:restored_version]
      pattern[:restored_version] = article_version.meta[:restored_version]
    end
    pattern
  end

  def attachments_hash(article_version)
    attachments = article_version.meta[:attachments] || []
    attachment_ids = attachments.map { |attachement| attachement[:id] }
    valid_attachments = if attachment_ids.present?
                          Account.current.attachments.where(id: attachment_ids).pluck(:id)
                        else
                          []
                        end
    attachments.map do |attachement|
      attachement[:deleted] = !valid_attachments.include?(attachement[:id])
      attachement
    end
    attachments
  end

  def cloud_files_hash(article_version)
    article_version.meta[:cloud_files] || []
  end

  def versions_count(article_or_account)
    article_or_account.reload.solution_article_versions.count
  end

  def get_latest_version(article)
    article.reload.solution_article_versions.latest.first
  end

  def get_live_version(article)
    article.reload.solution_article_versions.latest.where(live: true).first
  end

  def versions_thumbs_up_count(article)
    article.solution_article_versions.sum(&:thumbs_up)
  end

  def versions_thumbs_down_count(article)
    article.solution_article_versions.sum(&:thumbs_down)
  end

  def assert_version_published(article_version)
    assert_equal article_version.status, Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
  end

  def assert_version_draft(article_version)
    assert_equal article_version.status, Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]
  end

  def assert_version_live(article_version)
    assert article_version.live
  end

  def assert_version_not_live(article_version)
    assert !article_version.live
  end

  def assert_version_discarded(article_version)
    assert article_version.status, Solution::Article::STATUS_KEYS_BY_TOKEN[:discarded]
  end

  def assert_version_state(article_version, states)
    states.each do |state|
      safe_send("assert_version_#{state}", article_version)
    end
  end

  def should_create_version(article)
    count = versions_count(article)
    yield
    new_count = versions_count(article)
    assert_equal count + 1, new_count
    get_latest_version(article)
  end

  def should_delete_version(article)
    count = versions_count(article)
    yield
    new_count = versions_count(article)
    assert_equal count - 1, new_count
    get_latest_version(article)
  end

  def should_create_draft_version(article)
    count = versions_count(article)
    yield
    new_count = versions_count(article)
    assert_equal count + 1, new_count
    latest_version = get_latest_version(article)
    assert_version_draft(latest_version)
    latest_version
  end

  def should_create_published_version(article)
    count = versions_count(article)
    yield
    new_count = versions_count(article)
    assert_equal count + 1, new_count
    latest_version = get_latest_version(article)
    assert_version_published(latest_version)
    # TODO : should we need to do live check?
    latest_version
  end

  def should_destroy_version(article)
    count = versions_count(article)
    yield
    new_count = versions_count(article)
    assert_equal count - 1, new_count
  end

  def should_not_create_version(article)
    count = versions_count(article)
    yield
    new_count = versions_count(article)
    assert_equal count, new_count
  end

  def stub_version_session(session)
    Solution::ArticleVersion.any_instance.stubs(:session).returns(session)
    yield
  ensure
    Solution::ArticleVersion.any_instance.unstub(:session)
  end

  def stub_version_content(content = '{"title": "title", "description":"description"}')
    AwsWrapper::S3Object.stubs(:read).returns(content)
    yield
  ensure
    AwsWrapper::S3Object.unstub(:read)
  end

  def attachment_size_validation_error_pattern(cumulative_size)
    {
      code: 'article_version_file_size_exceeded',
      message: "Restore failed. The total attachment(s) in the selected version and the current version exceeds the #{cumulative_size}MB limit."
    }
  end
end
