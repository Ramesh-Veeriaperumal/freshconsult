class Freshcaller::Agent < ActiveRecord::Base
  include RepresentationHelper
  acts_as_api

  api_accessible :api do |fc|
    fc.add proc { |object| object.user.id }, as: :id
    fc.add proc { |object| object.user.name }, as: :name
    fc.add proc { |object| object.user.email }, as: :email
  end
end
