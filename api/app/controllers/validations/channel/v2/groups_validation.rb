# frozen_string_literal: true

module Channel::V2
  class GroupsValidation < ::ApiValidation
    attr_accessor :meta

    validates :meta, presence: true, on: :sync
  end
end
