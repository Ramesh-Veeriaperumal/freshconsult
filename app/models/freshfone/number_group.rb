class Freshfone::NumberGroup < ActiveRecord::Base
  self.table_name = :freshfone_number_groups
  belongs_to_account
  belongs_to :freshfone_number, :class_name => "Freshfone::Number"
  belongs_to :group

  def self.build_and_save(to_be_add, to_be_remove, freshfone_number)
    to_be_added = to_be_add.split(",")
    to_be_removed = to_be_remove.split(",")
    add_groups_to_number(to_be_added, freshfone_number) unless to_be_added.blank?
    remove_groups_from_number(to_be_removed, freshfone_number)
  end

  private
    def self.add_groups_to_number(to_be_added, freshfone_number)
      valid_groups = freshfone_number.account.groups.find(:all, :conditions => {:id => to_be_added})
      valid_groups.each { |group| self.create(:group_id => group.id, :freshfone_number_id =>  freshfone_number.id, :account_id => freshfone_number.account_id) }
    end

    def self.remove_groups_from_number(to_be_removed, freshfone_number)
      self.delete_all(:group_id => to_be_removed) unless to_be_removed.blank?
    end
end