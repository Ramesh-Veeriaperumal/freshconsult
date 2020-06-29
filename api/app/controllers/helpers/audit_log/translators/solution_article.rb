module AuditLog::Translators::SolutionArticle
  include Helpdesk::ApprovalConstants
  include Solution::Constants

  def readable_solution_article_changes(model_changes)
    model_changes.each do |key, value|
      case key
      when :tags
        model_changes[key][:added_tags].map! { |tag| { name: tag } } if model_changes[key].key?(:added_tags)
        model_changes[key][:removed_tags].map! { |tag| { name: tag } } if model_changes[key].key?(:removed_tags)
      when :description
        model_changes[key] = ''
      when :approval_status
        model_changes[key] = case value
                             when [nil, approval_status(:in_review)]
                               [t('draft'), t('in_review')]
                             when [nil, approval_status(:approved)]
                               [t('draft'), t('approved')]
                             when [approval_status(:in_review), approval_status(:approved)]
                               [t('in_review'), t('approved')]
                             when [approval_status(:in_review), nil]
                               model_changes.key?(:draft_exists) ? [t('in_review'), t('published')] : [t('in_review'), t('draft')]
                             when [approval_status(:approved), nil]
                               discard_approval_record_or_publish_approved_article(model_changes)
                             else
                               value
                             end
      when :status
        model_changes[key] = unpublish_activity?(value) ? [t('published'), t('unpublished')] : [t('draft'), t('published')]
      else
        next
      end
    end
    model_changes = { reset_ratings: '' } if reset_rating_pattern?(model_changes)
    model_changes
  end

  # translate
  def t(status)
    I18n.t("admin.audit_log.solution_article.#{status}")
  end

  def approval_status(token)
    Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[token]
  end

  def discard_approval_record_or_publish_approved_article(model_changes)
    # When an approved article is edited, there will be no change in draft_exists attribute, but approval record will be discarded.
    # When an approved article is published, draft_exists attribute will be [1, 0] and approval record will be discarded.
    model_changes.key?(:draft_exists) ? [t('approved'), t('published')] : [t('approved'), t('draft')]
  end

  def unpublish_activity?(status)
    status == [Solution::Constants::STATUS_KEYS_BY_TOKEN[:published], Solution::Constants::STATUS_KEYS_BY_TOKEN[:draft]]
  end

  def reset_rating_pattern?(model_changes)
    (AuditLogConstants::RESET_RATING_FIELDS - model_changes.keys).blank?
  end
end
