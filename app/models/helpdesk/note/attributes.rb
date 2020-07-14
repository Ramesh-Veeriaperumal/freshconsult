# This module is an extension for Helpdesk::Note
# This module is a wrapper between riak and mysql

class Helpdesk::Note < ActiveRecord::Base
  attr_accessor :note_body_content, :rollback_note_body, :previous_value

  # This method is defined only for alias method chaining
  def body
    self.read_attribute(:body)
  end

  # This method is defined only for alias method chaining
  def body_html
    self.read_attribute(:body_html)
  end

  def full_text
    (note_body && note_body.full_text) ? note_body.full_text : read_attribute(:body)
  end

  def full_text_html
    (note_body && note_body.full_text_html) ? note_body.full_text_html : read_attribute(:body_html)
  end

  # construction of note_body based on params returns a Helpdesk::NoteBody object
  # this also gets called when build_note_body is called on Helpdesk::Note object
  def note_body_attributes=(options={})
    if self.note_body_content && (self.note_body_content.class == Helpdesk::NoteBody)
      self.previous_value = self.note_body_content
    end
    self.note_body_content = Helpdesk::NoteBody.new(options)
    self.note_body_content.body_html_changed = true
    self.note_body_content
  end

  # note_body association between Helpdesk::Note and Helpdesk::NoteBody
  # has_one relationship is not defined
  # this method takes care of the association
  def note_body
    self.note_body_content ||= fetch
  end

  # returns note_bodies body
  def body_with_note_body
    (note_body && note_body.body) ? note_body.body : self.read_attribute(:body)
  end

  # returns note_bodies body_html
  def body_html_with_note_body
    (note_body && note_body.body_html) ? note_body.body_html : self.read_attribute(:body_html)
  end

  # When ever build_note_body on Helpdesk::Note object is called
  # :note_body_attributes= gets called
  alias_method :build_note_body, :note_body_attributes=

  # when ever Helpdesk::Note.new.body method is called
  # it calls body_with_note_body
  alias_method_chain :body, :note_body

  # when ever Helpdesk::Note.new.body_html method is called
  # it calls body_html_with_note_body
  alias_method_chain :body_html, :note_body

  # Return a Helpdesk::NoteBody object if it is present in riak
  # Returns a Helpdesk::NoteOldBody object from mysql  if the element is not found in riak
  # Returns a empty Helpdesk::NoteBody if it is not present in riak as well as in mysql
  def fetch
    begin
      return Helpdesk::NoteBody.new unless self.id
      note_body = safe_send("read_from_#{$primary_cluster}") 
      if note_body
        return note_body
      else
        safe_send("read_from_#{$secondary_cluster}") 
      end
    rescue Exception => e
      safe_send("read_from_#{$secondary_cluster}") 
    end
  end
  
  # the following code will get executed only in development
  # no operations
  def no_op
  end

  alias_method :read_from_none, :no_op
  alias_method :create_in_none, :no_op
  alias_method :update_in_none, :no_op
  alias_method :delete_in_none, :no_op
  alias_method :rollback_in_none, :no_op
end
