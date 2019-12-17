module Solution::ArticleFilterScoper
  extend ActiveSupport::Concern
  # [ TOKEN, STRING, STATUS_VALUE, TABLE_VALUE]
  STATUS_FILTER = [
    [:draft,     'solutions.status.draft',        1, 1],
    [:published, 'solutions.status.published',    2, 2],
    [:outdated, 'solutions.status.outdated',      3, 0], # only used in article versions.
    [:in_review, 'solutions.status.in_review',    4, 1],
    [:approved, 'solutions.status.approved',      5, 2]
  ].freeze

  STATUS_FILTER_BY_KEY = Hash[*STATUS_FILTER.map { |i| [i[2], i[1]] }.flatten]
  STATUS_FILTER_BY_TOKEN = Hash[*STATUS_FILTER.map { |i| [i[0], i[2]] }.flatten]
  STATUS_VALUE_IN_TABLE_BY_KEY = Hash[*STATUS_FILTER.map { |i| [i[2], i[3]] }.flatten]
  included do
    scope :by_status, lambda { |status, approver|
      status = status.to_i
      # published article can have draft. thus draft filter is handled by join type
      if status == STATUS_FILTER_BY_TOKEN[:draft] && Account.current.article_approval_workflow_enabled?
        join_condition = format(%(LEFT JOIN helpdesk_approvals ON solution_drafts.article_id = helpdesk_approvals.approvable_id AND helpdesk_approvals.account_id = %{account_id}), account_id: Account.current.id)
        condition = format(%(helpdesk_approvals.id is NULL))
        {
          joins: join_condition,
          conditions: [condition]
        }
      elsif status == STATUS_FILTER_BY_TOKEN[:published]
        where(status: status.to_i)
      elsif status == STATUS_FILTER_BY_TOKEN[:in_review] || status == STATUS_FILTER_BY_TOKEN[:approved]
        approval_status = STATUS_VALUE_IN_TABLE_BY_KEY[status]
        join_condition = format(%(INNER JOIN helpdesk_approvals ON solution_articles.id = helpdesk_approvals.approvable_id AND approvable_type = 'Solution::Article' AND helpdesk_approvals.account_id = %{account_id}), account_id: Account.current.id)
        condition = format(%(helpdesk_approvals.approval_status = %{approval_status}), approval_status: approval_status)
        if approver.present?
          join_condition += format(%( INNER JOIN helpdesk_approver_mappings ON helpdesk_approver_mappings.approval_id = helpdesk_approvals.id AND helpdesk_approver_mappings.account_id = %{account_id}), account_id: Account.current.id)
          condition += format(%( AND helpdesk_approver_mappings.approver_id= %{approver}), approver: approver.to_i)
        end
        {
          joins: join_condition,
          conditions: [condition]
        }
      end
    }

    scope :by_outdated, lambda { |value|
      where(outdated: value)
    }

    scope :by_category, lambda { |category_ids|
      {
        joins: format(%(AND solution_articles.account_id = solution_article_meta.account_id
                    AND solution_folder_meta.account_id = solution_article_meta.account_id AND
                    solution_articles.account_id = %{account_id}), account_id: Account.current.id),
        conditions: ['solution_folder_meta.solution_category_meta_id IN (?)', category_ids]
      }
    }

    scope :by_folder, lambda { |folder_ids|
      {
        joins: format(%(AND solution_article_meta.account_id = solution_articles.account_id AND
                    solution_articles.account_id = %{account_id}), account_id: Account.current.id),
        conditions: ['solution_article_meta.solution_folder_meta_id IN (?)', folder_ids]
      }
    }

    scope :by_tags, lambda { |tag_names|
      {
        joins: format(%(INNER JOIN helpdesk_tag_uses ON helpdesk_tag_uses.taggable_id = solution_articles.id AND
                    helpdesk_tag_uses.taggable_type = 'Solution::Article' AND
                    solution_articles.account_id = helpdesk_tag_uses.account_id
                    INNER JOIN helpdesk_tags ON helpdesk_tags.id = helpdesk_tag_uses.tag_id AND
                    helpdesk_tag_uses.account_id = helpdesk_tags.account_id AND
                    solution_articles.account_id = %{account_id}), account_id: Account.current.id),
        conditions: ['helpdesk_tags.name IN (?)', tag_names]
      }
    }

    scope :by_created_at, lambda { |start_date, end_date|
      where(
        'solution_articles.created_at >= ? AND solution_articles.created_at <=?',
        DateTime.parse(start_date),
        DateTime.parse(end_date)
      )
    }

    scope :by_last_modified, lambda { |start_date, end_date, only_draft|
      # if status filter is draft we need to query only in drafts table.
      if only_draft
        where(
          'solution_drafts.modified_at between ? and ?',
          DateTime.parse(start_date),
          DateTime.parse(end_date)
        )
      else
        where(
          'IFNULL(solution_drafts.modified_at, solution_articles.modified_at) between ? and ?',
          DateTime.parse(start_date),
          DateTime.parse(end_date)
        )
      end
    }

    scope :by_author, lambda { |author, only_draft|
      # if status filter is draft we need to query only in drafts table.
      author = author.to_i
      if author == -1
        cond = format(%(users.id is NULL OR helpdesk_agent=0 OR users.deleted=1))
        cond += format(%( AND solution_articles.status=%{draft_status}), draft_status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]) if only_draft
        {
          joins: format(%(LEFT JOIN users ON users.id=solution_articles.user_id  AND users.account_id = %{account_id} ), account_id: Account.current.id),
          conditions: [cond]
        }
      else
        only_draft ? where(format(%(solution_drafts.user_id=%{user_id} OR solution_articles.user_id=%{user_id}), user_id: author)) : where(format(%(solution_articles.user_id=%{user_id} OR IFNULL(solution_drafts.user_id, solution_articles.modified_by)=%{user_id}), user_id: author))
      end
    }
  end
end
