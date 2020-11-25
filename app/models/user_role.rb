# frozen_string_literal: true

class UserRole < ActiveRecord::Base
  belongs_to_account
  belongs_to :user
  belongs_to :role

  after_commit ->(obj) { obj.user.clear_user_roles_cache }
end
