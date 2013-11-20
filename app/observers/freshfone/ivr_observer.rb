class Freshfone::IvrObserver < ActiveRecord::Observer
	observe Freshfone::Ivr

	def before_validation_on_update(freshfone_ivr)
		build_menus_and_relations(freshfone_ivr) if freshfone_ivr.any_ivr_data_changed?
	end

	def before_save(freshfone_ivr)
		handle_attachements(freshfone_ivr)
	end

	def before_create(freshfone_ivr)
		build_seed_menu(freshfone_ivr)
	end

	private
		def build_menus_and_relations(freshfone_ivr)
			build_menus(freshfone_ivr)
			compute_relations(freshfone_ivr)
		end

		def build_menus(freshfone_ivr)
			freshfone_ivr.menus_list ||= begin
				(freshfone_ivr.get_ivr_data || {}).map do |k, v|
					Freshfone::Menu.new({
						:attachment_id => v["attachment_id"].blank? ? nil : v["attachment_id"].to_i,
						:children => [],
						:children_hash => {},
						:message => v["message"], 
						:message_type => v["message_type"].to_i,
						:menu_options => v["options"],
						:menu_id => k.to_i,
						:name => k.to_i,
						:menu_name => v["menu_name"],
						:parent => nil,
						:recording_url => v["recording_url"]
					})
				end.sort_by { |m| m.menu_id }
			end
		end

		def compute_relations(freshfone_ivr)
			(freshfone_ivr.relations || {}).each_pair do |k, v|
				return if (parent = freshfone_ivr.menus_hash[k.to_i]).blank?
				v.each do |child_id|
					return if (child = freshfone_ivr.menus_hash[child_id]).blank?
					parent << child
				end 
			end
		end

		def build_seed_menu(freshfone_ivr)
			freshfone_ivr.ivr_data = { 0 => seed_menu }
		end

		def seed_menu
			Freshfone::Menu.new({
				:attachment_id => nil,
				:options => [],
				:message_type => 2,
				:menu_id => 0,
				:children => [],
				:recording_url => nil,
				:name => 0,
				:menu_name => I18n.t('freshfone.admin.ivr.seed_menu_name'),
				:children_hash => {},
				:message => I18n.t('freshfone.admin.ivr.seed_message'),
				:parent => nil
			})
		end

		def handle_attachements(freshfone_ivr)
			freshfone_ivr.attachments.each { |a| a.save if a.new_record? }
			map_attachments(freshfone_ivr)
			set_ivr_data(freshfone_ivr)
		end

		def map_attachments(freshfone_ivr)
			(freshfone_ivr.attachments_hash || {}).each_pair do |menu_id, attachment|
				freshfone_ivr.menus_hash[menu_id].attachment_id = attachment.id
			end
		end
		
		
		def set_ivr_data(freshfone_ivr)
			return freshfone_ivr.ivr_draft_data = freshfone_ivr.menus_hash if freshfone_ivr.preview_mode

			freshfone_ivr.ivr_data = freshfone_ivr.menus_hash
		end
		
end