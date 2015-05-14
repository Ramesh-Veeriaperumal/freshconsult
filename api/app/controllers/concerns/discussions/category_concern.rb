module Discussions::CategoryConcern
  extend ActiveSupport::Concern
  included do
    prepend_before_filter { |c| c.requires_feature :forums } # this has to be revisited
  end

  private
    def scoper
      current_account.forum_categories
    end
end