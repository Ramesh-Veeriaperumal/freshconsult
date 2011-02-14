class Solution::Article < ActiveRecord::Base
   belongs_to :folder, :class_name => 'Solution::Folder'
   set_table_name "solution_articles"
   
   belongs_to :user, :class_name => 'User'
   has_many :attachments,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :dependent => :destroy
end
