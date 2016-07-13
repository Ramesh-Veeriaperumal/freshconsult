module Helpdesk::NotePropertiesMethods

  def build_notes_last_modified_user_hash(notes)
    @note_last_modified_user_hash = {}
    return unless notes.present?
    notes_hash = Hash[ *notes.collect { |v| [ v.id.to_s, v.last_modified_user_id.to_s ] }.flatten ]
    users_to_fetch = notes_hash.values.uniq.reject(&:empty?)
    user_hash = if users_to_fetch.count > 0
      Hash[ *Account.current.users.where({:id => users_to_fetch}).collect { |v| [ v.id.to_s, v]}.flatten]
    else
      {}
    end
    @note_last_modified_user_hash = notes_hash.inject({}) do |hash, (k,v)|
      hash[k] = user_hash[v]; hash
    end
  end
end
