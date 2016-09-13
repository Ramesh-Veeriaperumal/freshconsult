# Todos in the chronology that they appear
todos = ["Signed up", "Activate your account", "Invite your teammates", "Add your own support email", "Set up an automation rule", "Configure your own custom domain", "Import your contacts"]
reminders = []
todos.each do |todo|
	reminders << {
	  :body => todo,
	  :deleted => 0,
	  :user_id => User.current.id,
	  :account_id => Account.current.id
	}
end
reminders.first[:deleted] = 1

Helpdesk::Reminder.seed_many(:account_id, :user_id, :body, reminders)
