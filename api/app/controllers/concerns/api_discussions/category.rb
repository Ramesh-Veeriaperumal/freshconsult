module ApiDiscussions::Category
  extend ActiveSupport::Concern

  included do
  end

  protected

    def scoper
		current_account.forum_categories
	end

  private
end