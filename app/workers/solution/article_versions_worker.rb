class Solution::ArticleVersionsWorker < BaseWorker
  sidekiq_options queue: :kbase_article_versions_worker, retry: 4, failures: :exhausted

  def perform(args)
    args.symbolize_keys!

    @id = args[:id]
    @article_id = args[:article_id]
    @action = args[:action]
    @triggered_from = args[:triggered_from]

    Rails.logger.info "AVW::Running article version #{@action} [#{Account.current.id},#{@article_id},#{@id},#{@triggered_from}]"

    if @action == 'store'
      # for update action, article record should be available
      return unless article
      parent_record = @triggered_from == 'article' ? article : article.draft
      return unless parent_record
      @title = args[:title] || parent_record.title
      @description = args[:description] || parent_record.description
    end
    Rails.logger.info "AVW::Running article version #{@action} start"
    safe_send("#{@action}_version")
    Rails.logger.info "AVW::Running article version #{@action} end"
  rescue => e # rubocop:disable RescueStandardError
    Rails.logger.info "AVW::Exception while running article version #{@action} [#{Account.current.id},#{@article_id},#{@id}] #{e.message} - #{e.backtrace}"
    NewRelic::Agent.notice_error(e, account: Account.current.id, description: "Exception while running article version #{@action} [#{Account.current.id},#{@article_id},#{@id}] #{e.message}")
  end

  private

    def payload
      {
        title: @title,
        description: @description
      }.to_json
    end

    # article version and article record won't be there for destroy action, use this only for update action
    def article
      @article ||= Account.current.solution_articles.where(id: @article_id).first
    end

    def store_version
      Rails.logger.info "AVW::storing version in s3 #{s3_path}"
      AwsWrapper::S3.put(s3_bucket, s3_path, payload, server_side_encryption: 'AES256')
    end

    def destroy_version
      AwsWrapper::S3.delete(s3_bucket, s3_path)
    end

    def s3_path
      Solution::ArticleVersion.content_path(@article_id, @id)
    end

    def s3_bucket
      Solution::ArticleVersion.s3_bucket
    end
end
