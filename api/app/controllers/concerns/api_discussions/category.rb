module ApiDiscussions::Category
  extend ActiveSupport::Concern

  included do
  end

  protected

    def portal_scoper
		# Has to be checked when we introduce the ability to remove the categories from the main portal
		current_account.main_portal.forum_categories
	end

  private
end