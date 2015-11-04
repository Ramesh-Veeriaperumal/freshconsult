class Shortcut

	KEY_BINDINGS = {
		:global	=> {
			:help 				=> "?",
			:save				=> "mod+return",
			:cancel				=> "esc",
			:search				=> "/",
			:status_dialog 		=> "mod+alt+return",
			:save_cuctomization => "mod+shift+s"
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
			:ticket_new			=> "g n",
			:compose_email      => "g m"
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
			:toggle_list_view	=> "shift+v",
			:unwatch			=> "w",
			:delete				=> "#",
			:pickup 			=> "@",
			:spam				=> "!",
			:close				=> "~",
			:silent_close		=> "alt+shift+`",
			:undo				=> "z",
			:reply				=> "r",
			:forward			=> "f",
			:add_note			=> "n",
			:scenario			=> "s"
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
			:undo				=> "z",
			:expand 			=> "]",
			:select_watcher		=> "shift+w",
			:go_to_next			=> ['j', 'down'],
			:go_to_previous		=> ['k', 'up'],
			:scenario			=> "s"
		},
		:social_stream 			=> {
			:search				=> "s",
			:go_to_next			=> ['j', 'down'],
			:go_to_previous		=> ['k', 'up'],
			:open_stream		=> ["space", "return"],
			:close 				=> "esc",
			:reply				=> "r",
			:retweet			=> "shift+r"
		},
		:portal_customizations  => {
			:preview			=> "mod+shift+p"
		},
		:discussions => {
			:toggle_following => "w",
			:add_follower => "shift+w",
			:reply_topic => "r"
		}
	}

	MODIFIER_KEYS = {
		:ctrl 		=> {
			:mac 		=> "&#8984;",
			:windows 	=> "Ctrl",
			:linux 		=> "Ctrl"
		},
		:shift 		=> {
			:mac 		=> "&#8679;",
			:windows 	=> "Shift",
			:linux	 	=> "Shift"
		},
		:alt 		=> {
			:mac 		=> "&#8997;",
			:windows 	=> "Alt",
			:linux 		=> "Alt"
		},
		:enter		=> {
			:mac 		=> "Return",
			:windows 	=> "Enter",
			:linux 		=> "Enter"
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
