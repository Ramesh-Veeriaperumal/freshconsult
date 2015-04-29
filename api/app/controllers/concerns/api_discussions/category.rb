module ApiDiscussions::Category
  extend ActiveSupport::Concern

    included do
      before_filter { |c| c.requires_feature :forums }    
    end

    protected

    def scoper
  		current_account.forum_categories
  	end

    private
end