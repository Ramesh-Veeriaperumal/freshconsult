# Monkey patching fix as rails version does allow updating sprocket gem version
# Can be removed after rails upgrade
# Vulnerability -> https://blog.heroku.com/rails-asset-pipeline-vulnerability#how-do-i-fix-it
# Patch obtained from -> https://groups.google.com/forum/#!topic/rubyonrails-security/ft_J--l55fM

Sprockets::Server.module_eval do
 private

   def forbidden_request?(path)
     path.include?('..') || Pathname.new(path).absolute? || path.include?('://')
   end
end
