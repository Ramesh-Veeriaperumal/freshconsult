module Solution::ArticleFilterScoper
  extend ActiveSupport::Concern

  included do
    scope :by_status, lambda { |status|
      status = status.to_i
      # published article can have draft. thus draft filter is handled by join type
      if status == Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
        where(status: status.to_i)
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
