class EmailNotification < ActiveRecord::Base
  belongs_to :account
  
  #Notification types
  NEW_TICKET = 1
  TICKET_ASSIGNED_TO_GROUP = 2
  TICKET_ASSIGNED_TO_AGENT = 3
  COMMENTED_BY_AGENT = 4
  #COMMENTED_BY_REQUESTER = 5
  REPLIED_BY_REQUESTER = 6
  TICKET_RESOLVED = 7
  TICKET_CLOSED = 8
  TICKET_REOPENED = 9
end
