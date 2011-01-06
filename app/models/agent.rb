class Agent < ActiveRecord::Base
  
  belongs_to :user, :class_name =>'User', :foreign_key =>'user_id'
  
  accepts_nested_attributes_for :user

end
