module SAAS::AddFeatureData
  def handle_round_robin_add_data
    Role.add_manage_availability_privilege account
  end

  def handle_multi_language_add_data
    ::Community::SolutionBinarizeSync.perform_async
  end

  def handle_article_versioning_add_data
    ::Solution::ArticleVersionsMigrationWorker.perform_async(action: 'add')
  end
end