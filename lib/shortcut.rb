class Shortcut

	KEY_BINDINGS = {
		:global	=> {
			:help 				=> "?",
			:save				=> "mod+return",
			:cancel				=> "esc",
			:search				=> "/"
		},
		:app_nav => {
			:dashboard			=> "g d",
			:tickets 			=> "g t",
			:social 			=> "g e",
			:solutions 			=> "g s",
			:forums 			=> "g f",
			:customers 			=> "g c",
			:reports 			=> "g r",
			:admin 				=> "g a",
			:ticket_new			=> "g n"
		},
		:pagination	=> {
			:previous			=> "alt+left",
			:next				=> "alt+right"
		},
		:ticket_list => {
			:ticket_show		=> "return",
			:select 			=> "x",
			:select_all 		=> "shift+x",
			:show_description	=> "space",
			:go_to_next			=> ['j', 'down'],
			:go_to_previous		=> ['k', 'up'],
			:toggle_list_view	=> "shift+v",
			:unwatch			=> "w",
			:delete				=> "#",
			:pickup 			=> "@",
			:spam				=> "!",
			:close				=> "~",
			:silent_close		=> "alt+shift+`",
			:undo				=> "z"
		},
		:ticket_detail	=> {
			:toggle_watcher		=> "w",
			:reply 				=> "r",
			:forward			=> "f",
			:add_note			=> "n",
			:close				=> "~",
			:silent_close		=> "alt+shift+`",
			:add_time			=> "m",
			:spam				=> "!",
			:delete				=> "#",
			:show_activities_toggle	=> "}",
			:properties			=> "p",
			:expand				=> "]",
			:undo				=> "z"
		}
	}

	MODIFIER_KEYS = {
		:ctrl 		=> {
			:mac 		=> "&#8984;",
			:windows 	=> "Ctrl"
		},
		:shift 		=> {
			:mac 		=> "&#8679;",
			:windows 	=> "Shift"
		},
		:alt 		=> {
			:mac 		=> "&#8997;",
			:windows 	=> "Alt"
		},
		:capslock 	=> {
			:mac 		=> "&#8682;",
			:windows 	=> "Caps Lock"
		}
	}

	def self.get(key)
		keys = key.split('.')
		current = KEY_BINDINGS
		(keys || []).each do |k|
			k = k.to_sym
			break unless current.has_key?(k)
			return current[k] unless current[k].is_a? Hash
			current = current[k]
		end

		return nil
	end

end
