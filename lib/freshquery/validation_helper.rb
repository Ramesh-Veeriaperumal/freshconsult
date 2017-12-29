module Freshquery::ValidationHelper
  extend ActiveSupport::Concern

  included do
    include Singleton
  end
end
