module ApiDiscussions::DiscussionsTopic
  extend ActiveSupport::Concern

    included do
      before_filter { |c| c.requires_feature :forums }    
    end

    protected

    def scoper
  		current_account.topics
  	end

    private
end