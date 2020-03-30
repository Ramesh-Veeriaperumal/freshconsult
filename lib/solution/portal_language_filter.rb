class Solution::PortalLanguageFilter
  def initialize(portal_id = nil, language_id = Account.current.language_object.id)
    @portal_id = portal_id
    @lang_id = language_id
  end

  # Returns solution_categores for a particular portal(if specified) and language
  # Excludes default categories.
  def categories
    sol_cats = Account.current.solution_categories
    sol_cats = if @portal_id.present?
                 sol_cats.joins(solution_category_meta: [portal_solution_categories: :portal])
                         .where(portals: { id: @portal_id, account_id: Account.current.id })
                         .where(portal_solution_categories: { account_id: Account.current.id })
               else
                 sol_cats.joins(:solution_category_meta)
               end
    sol_cats.where(solution_category_meta: { is_default: 0, account_id: Account.current.id })
            .where(solution_categories: { language_id: @lang_id })
  end

  def folders
    sol_folders = Account.current.solution_folders
    sol_folders = if @portal_id.present?
                 sol_folders.joins(solution_folder_meta: [solution_category_meta: :portal_solution_categories])
                         .where(portal_solution_categories: { account_id: Account.current.id, portal_id: @portal_id })
               else
                 sol_folders.joins(solution_folder_meta: :solution_category_meta)
               end
    sol_folders.where(solution_category_meta: { is_default: 0, account_id: Account.current.id })
            .where(solution_folder_meta: { account_id: Account.current.id })
            .where(solution_folders: { language_id: @lang_id })
  end

  # Returns unassociated categories.
  # For all portal, it's same. As its not portal specific.
  def unassociated_categories
    Account.current.solution_categories
           .where(id: Account.current.solution_category_meta
                       .joins('LEFT JOIN portal_solution_categories on solution_category_meta.id = portal_solution_categories.solution_category_meta_id')
                       .where('portal_solution_categories.solution_category_meta_id IS NULL')
                       .where(portal_solution_categories: { account_id: Account.current.id })
                       .select('solution_category_meta.id'))
  end

  def article_meta
    sol_art_meta = Account.current.solution_article_meta
    sol_art_meta = if @portal_id.present?
                     sol_art_meta.joins(solution_folder_meta: [solution_category_meta: [portal_solution_categories: :portal]])
                                 .where(portals: { id: @portal_id, account_id: Account.current.id })
                                 .where(portal_solution_categories: { account_id: Account.current.id })
                   else
                     sol_art_meta.joins(solution_folder_meta: :solution_category_meta)
                   end
    sol_art_meta.where(solution_folder_meta: { account_id: Account.current.id })
  end

  def all_article_translations
    sol_arts = Account.current.solution_articles
    sol_arts = if @portal_id.present?
                 sol_arts.joins(solution_article_meta: [solution_folder_meta: [solution_category_meta: [portal_solution_categories: :portal]]])
                         .where(portals: { id: @portal_id, account_id: Account.current.id })
                         .where(portal_solution_categories: { account_id: Account.current.id })
               else
                 sol_arts.joins(solution_article_meta: [solution_folder_meta: :solution_category_meta])
               end
    sol_arts.where(solution_category_meta: { account_id: Account.current.id })
            .where(solution_folder_meta: { account_id: Account.current.id })
            .where(solution_article_meta: { account_id: Account.current.id })
  end

  def articles
    all_article_translations.where(solution_articles: { language_id: @lang_id })
  end

  def published_articles
    articles.where(status: Solution::Constants::STATUS_KEYS_BY_TOKEN[:published])
  end

  def my_articles
    articles.where(solution_articles: { user_id: User.current.id })
  end

  def outdated_articles
    articles.where(solution_articles: { outdated: true })
  end

  # Returns all drafts
  # Articles in-review, approved etc are also considered as drafts
  def drafts
    sol_drafts = Account.current.solution_drafts
    sol_drafts = if @portal_id.present?
                   sol_drafts.joins(article: [solution_article_meta: [solution_folder_meta: [solution_category_meta: [portal_solution_categories: :portal]]]])
                             .where(portals: { id: @portal_id, account_id: Account.current.id })
                             .where(portal_solution_categories: { account_id: Account.current.id })
                 else
                   sol_drafts.joins(article: [solution_article_meta: [solution_folder_meta: :solution_category_meta]])
                 end
    sol_drafts.where(solution_category_meta: { account_id: Account.current.id })
              .where(solution_folder_meta: { account_id: Account.current.id })
              .where(solution_article_meta: { account_id: Account.current.id })
              .where(solution_articles: { account_id: Account.current.id, language_id: @lang_id })
  end

  # Returns my drafts
  # Includes in-review/approved state drafts
  def all_my_drafts
    drafts.where(user_id: User.current.id)
  end

  # Returns my drafts
  # Excludes in-review/approved state drafts
  def my_drafts
    if Account.current.article_approval_workflow_enabled?
      all_my_drafts.joins(format(%(LEFT JOIN helpdesk_approvals ON solution_drafts.article_id = helpdesk_approvals.approvable_id AND helpdesk_approvals.account_id = %{account_id} AND approvable_type = 'Solution::Article'), account_id: Account.current.id))
                   .where('helpdesk_approvals.id IS NULL')
    else
      all_my_drafts
    end
  end

  # Returns all approvals
  # Can be in in-review/approved state
  def approvals
    Account.current.helpdesk_approvals
           .where(approvable_id: articles.select('solution_articles.id'), approvable_type: 'Solution::Article')
           .where(helpdesk_approvals: { account_id: Account.current.id })
  end

  # Aggregate count of articles group by approval-status
  def articles_count_by_approval_status
    Account.current.helpdesk_approvals
           .where(approvable_id: articles.select('solution_articles.id'), approvable_type: 'Solution::Article')
           .group(:approval_status)
           .count
  end

  # Returns tickets created from articles
  # Excludes spam and deleted article-tickets
  def all_feedback
    Account.current.tickets
           .where(id: Account.current.article_tickets
                       .where(article_id: articles.select('solution_articles.id'), ticketable_type: 'Helpdesk::Ticket')
                       .select(:ticketable_id), spam: false, deleted: false)
  end

  # Returns tickets created from user-articles
  # Excludes spam and deleted article-tickets
  def my_feedback
    Account.current.tickets
           .where(id: Account.current.article_tickets
                       .where(article_id: my_articles.select('solution_articles.id'), ticketable_type: 'Helpdesk::Ticket')
                       .select(:ticketable_id), spam: false, deleted: false)
  end
end
