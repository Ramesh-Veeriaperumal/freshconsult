Factory.define :admin, :class => User do |u|
  u.email "shan@freshdesk.com"
  u.password "123456"
  u.password_confirmation "123456"
  u.role_token "admin"
end

Factory.define :agent, :class => User do |u|
  u.email "agent@freshdesk.com"
  u.password "123456"
  u.password_confirmation "123456"
  u.role_token "poweruser"
end

Factory.define :end_user , :class => User do |u|
  u.email "eu@freshdesk.com"
  u.password "123456"
  u.password_confirmation "123456"
  u.role_token "customer"
end

Factory.define :invalid_user , :class => User do |u|
end
