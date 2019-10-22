module Solution::ArticleVersioning
  extend ActiveSupport::Concern

  included do
    def version_create_or_update(record, exclude_article_payload = false)
      @delegator = if record.instance_of? Solution::Article
                     ArticleHandler.new(record)
                   else
                     DraftHandler.new(record)
                   end
      @delegator.exclude_article_payload = exclude_article_payload
      @delegator.create_or_update
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
      !latest_version || latest_version.user_id != user_id || !same_session?
    end

    def latest_version
      @latest_version = article_version_scoper.latest.first unless instance_variable_defined? :@latest_version
      @latest_version
    end

    def same_session?
      redis_session = latest_version.session
      redis_session ? redis_session == session : false
    end

    def mark_unlive
      live_version = article_version_scoper.where(live: true).first
      if live_version
        live_version.unlive!
      end
    end

    def assign_version_no(version_record)
      version_record.version_no = (article_version_scoper.maximum(:version_no) || 0) + 1 if create_version?
    end

    def exclude_article_payload=(val)
      @exclude_article_payload = val
    end

    def assign_common_attributes(version_record)
      assign_version_no(version_record)
      version_record.exclude_article_payload = @exclude_article_payload
      version_record.user_id = User.current.id
      Solution::ArticleVersion::COMMON_ATTRIBUTES.each do |attribute|
        version_record.safe_send("#{attribute}=", safe_send(attribute))
      end
    end
  end

  # wrapper for version creation from article record
  class ArticleHandler < SimpleDelegator
    include BaseHandler

    def assign_version_attributes(version_record)
      assign_common_attributes(version_record)
      version_record.status = status
      mark_unlive if (published? && latest_version) || unpublishing
      version_record.published_by = User.current.id if published?
      version_record.live = published?
      version_record.triggered_from = 'article'
    end

    def build_version_record
      solution_article_versions.build
    end

    def article_version_scoper
      @article_version_scoper ||= solution_article_versions
    end
  end

  # wrapper for version creation from draft record
  class DraftHandler < SimpleDelegator
    include BaseHandler

    def assign_version_attributes(version_record)
      assign_common_attributes(version_record)
      version_record.status = Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]
      mark_unlive if article.unpublishing
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
  end
end
