module ApiDiscussions::Category
  extend ActiveSupport::Concern

    included do
      prepend_before_filter { |c| c.requires_feature :forums } # this has to be revisited
    end

    protected

    def scoper
  		current_account.forum_categories
  	end

    private
end