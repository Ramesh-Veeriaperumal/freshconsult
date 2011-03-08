Factory.define :admin, :class => User do |u|
  u.email "shan@freshdesk.com"
  u.password "123456"
  u.password_confirmation "123456"
  u.user_role "1"
end

Factory.define :agent, :class => User do |u|
  u.email "agent@freshdesk.com"
  u.password "123456"
  u.password_confirmation "123456"
  u.user_role "2"
end

Factory.define :end_user , :class => User do |u|
  u.email "eu@freshdesk.com"
  u.password "123456"
  u.password_confirmation "123456"
  u.user_role "3"
end

Factory.define :invalid_user , :class => User do |u|
end
