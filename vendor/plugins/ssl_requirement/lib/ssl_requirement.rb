# Copyright (c) 2005 David Heinemeier Hansson
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
module SslRequirement
  def self.included(controller)
    controller.extend(ClassMethods)
    controller.before_filter(:ensure_proper_protocol)
  end

  module ClassMethods
    # Specifies that the named actions requires an SSL connection to be performed (which is enforced by ensure_proper_protocol).
    def ssl_required(*actions)
      write_inheritable_array(:ssl_required_actions, actions)
    end

    def ssl_allowed(*actions)
      write_inheritable_array(:ssl_allowed_actions, actions)
    end
  end
  
  protected
    # Returns true if the current action is supposed to run as SSL
    def ssl_required?
      (self.class.read_inheritable_attribute(:ssl_required_actions) || []).include?(action_name.to_sym)
    end
    
    def ssl_allowed?
      (self.class.read_inheritable_attribute(:ssl_allowed_actions) || []).include?(action_name.to_sym)
    end
    
  private
  
    def ensure_proper_protocol
      return true if !Rails.env.production? || ssl_allowed? || (request.ssl? && ssl_required?)

      if !request.ssl? && (ssl_required? || main_portal_with_ssl? || cnamed_portal_with_ssl?)
        redirect_to "https://" + request.host + request.request_uri
        flash.keep
        return false
      elsif request.ssl? && cnamed_portal_without_ssl?
        redirect_to "http://" + request.host + request.request_uri
        flash.keep
        return false
      end      
      return true
    end

    def main_portal_with_ssl?
      (request.host == current_account.full_domain) && current_account.ssl_enabled? 
    end

    def cnamed_portal_with_ssl?
      (request.host == current_portal.portal_url) && current_portal.ssl_enabled?
    end

    def cnamed_portal_without_ssl?
      (request.host == current_portal.portal_url) && !current_portal.ssl_enabled?
    end

end