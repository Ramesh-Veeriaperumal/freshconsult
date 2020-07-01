module Solution::ArticleVersioning
  extend ActiveSupport::Concern

  include Redis::Redlock

  included do
    def version_create_or_update(record, from_migration_worker = false)
      @delegator = if record.instance_of? Solution::Article
                     ArticleHandler.new(record)
                   else
                     DraftHandler.new(record)
                   end
      @delegator.from_migration_worker = from_migration_worker
      if Account.current.launched?(:article_versioning_redis_lock)
        raise 'Failed to acquire the lock for version creation' unless acquire_lock_and_run(key: @delegator.lock_key, ttl: 3000) { @delegator.create_or_update }
      else  
        @delegator.create_or_update
      end
    end

    def version_discard_or_destroy(record)
      @delegator = DraftHandler.new(record)
      @delegator.discard_or_destroy
    end
  end

  module BaseHandler
    def create_or_update
      if create_version?
        create_version
      else
        update_version
      end
    end

    def discard_or_destroy
      return unless latest_version # destroy(delete button) article should not do the below

      if (discarding || cancelling) && destroy_version?
        # if session is set and no discarding then article is being published
        article_version_scoper.latest.first.destroy
      elsif discarding # if session is not set, it is direct discard
        discard_draft_versions
      end
    end

    def update_version
      latest_version.upsert_s3 = true
      assign_version_attributes(latest_version)
      latest_version.update_attachments_info
      latest_version.save!
      latest_version
    end

    def create_version
      version_record = build_version_record
      assign_version_attributes(version_record)
      version_record.update_attachments_info
      version_record.save!
      version_record.set_session(session)
      version_record
    end

    def create_version?
      !latest_version || latest_version.user_id != current_user || !same_session?
    end

    def latest_version
      @latest_version = article_version_scoper.latest.first unless instance_variable_defined? :@latest_version
      @latest_version
    end

    def mark_unlive
      live_version = article_version_scoper.where(live: true).first
      live_version.unlive! if live_version
    end

    def assign_version_no(version_record)
      version_record.version_no = (article_version_scoper.maximum(:version_no) || 0) + 1 if create_version?
    end

    def from_migration_worker=(val)
      @from_migration_worker = val
    end

    def assign_common_attributes(version_record)
      assign_version_no(version_record)
      version_record.from_migration_worker = @from_migration_worker
      version_record.user_id = current_user
      Solution::ArticleVersion::COMMON_ATTRIBUTES.each do |attribute|
        version_record.safe_send("#{attribute}=", safe_send(attribute))
      end
    end

    def lock_key
      format(Redis::Keys::Others::ARTICLE_VERSION_LOCK_KEY, account_id: account_id, article_id: article_id)
    end
  end

  # wrapper for version creation from article record
  class ArticleHandler < SimpleDelegator
    include BaseHandler

    def assign_version_attributes(version_record)
      assign_common_attributes(version_record)
      version_record.status = status
      mark_unlive if (published? && latest_version) || unpublishing
      version_record.published_by = current_user if published?
      version_record.live = published?
      version_record.triggered_from = 'article'
    end

    def build_version_record
      solution_article_versions.build
    end

    def article_version_scoper
      @article_version_scoper ||= solution_article_versions
    end

    # check if same session incase publishing an article over published article before autosave
    def same_session?
      redis_session = latest_version.session
      redis_session ? redis_session == session : false
    end

    def current_user
      @current_user ||= User.current ? User.current.id : (modified_by || user_id)
      # When migration is run, current user will not be present. We need to take modified_by into consideration for article and user_id for draft
    end

    def article_id
      id
    end
  end

  # wrapper for version creation from draft record
  class DraftHandler < SimpleDelegator
    include BaseHandler

    def assign_version_attributes(version_record)
      assign_common_attributes(version_record)
      version_record.status = Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]
      mark_unlive if article.unpublishing
      version_record.restore(self.restored_version) if self.restored_version
      version_record.live = false
      version_record.triggered_from = 'draft'
    end

    def build_version_record
      article.solution_article_versions.build
    end

    def destroy_version?
      same_session?
    end

    def discard_draft_versions
      # while discarding draft, update discard status of article versions that are created after last published version
      last_published = article_version_scoper.latest.where(status: Solution::Article::STATUS_KEYS_BY_TOKEN[:published]).first
      draft_versions = article_version_scoper.where('version_no > ? and status != ?', last_published.version_no, Solution::Article::STATUS_KEYS_BY_TOKEN[:discarded])
      draft_versions.find_each(&:discard!)
    end

    def article_version_scoper
      @article_version_scoper ||= article.solution_article_versions
    end

    def same_session?
      return false if restored_version # restore should always create a new version

      redis_session = latest_version.session
      redis_session ? redis_session == session : false
    end

    def current_user
      @current_user ||= User.current ? User.current.id : user_id
      # When migration is run, current user will not be present. We need to take modified_by into consideration for article and user_id for draft
    end
  end
end
