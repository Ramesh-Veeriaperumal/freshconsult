class Admin::Skill < ActiveRecord::Base
  include RepresentationHelper

  acts_as_api

  api_accessible :skill_as_association do |g|
    g.add :id
    g.add :name
    g.add :account_id
  end
end
