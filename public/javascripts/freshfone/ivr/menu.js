var globalmenus = {},
	IvrMenu;
	var original_stringify = JSON.stringify;
(function ($) {
	"use strict";
	IvrMenu = function (ivr, jsonMenu) {
		this.realWorldName = "Menu";
		this.ivr = ivr;
		this.jsonMenu = jsonMenu;
		this.setDefaults();
		this.json_stringify = original_stringify;
		
	};
	IvrMenu.prototype = {
		init: function () {
			this.$dom = this.$menuContainer.find('fieldset:first');
			this.$addOptionElement = this.$menuContainer.find('.new-option');
			this.$title_input = this.$menuContainer.find('.menu-title');
			this.$rename_link = this.$menuContainer.find('[rel=rename]');
			this.$done_rename_link = this.$menuContainer.find('[rel=done-rename]');
		},
		build: function () {
			this.createMenu();
			this.addRelations();
			this.bindToThisMenu();
			if (this.menusCount() > 1) { this.ivr.hideAddMenuLink(this.menusList); }
			return this;
		},
		setDefaults: function () {
			this.menuId = (this.jsonMenu || {}).menuId || this.nextMenuIdAvailable();
			if (this.jsonMenu !== undefined) {
				this.menuName = this.jsonMenu.menuName;
			} else {
				this.menuName = this.realWorldName + " " + this.menuId;
				this.message = "This is " + this.realWorldName + " " + this.menuId;
			}
			this.nextOptionId = 0;
			this.options = [];
			this.assignedKeys = [];
		},
		createMenu: function () {
			this.buildFromTemplate();
			$('.new-menu').before(this.template);
			this.$menuContainer = $('[rel="new_menu"]:last').removeAttr('rel');
			this.init();
			
			this.afterMenuCreate();
		},
		afterMenuCreate: function () {
			if (!this.menuId) { this.$menuContainer.find('.close-btn').remove(); }
			if (this.jsonMenu === undefined) { this.ivr.addMenuToList(this.menuId, this.menuName); }

			globalmenus[this.menuId] = this.menusList[this.menuId] = this;
		},
		buildFromTemplate: function () {
			var template = $('#menu-template');
			template.find('div.select2-container').remove();
			var prefix = replacePrefix(freshfone.ivr_prefix, 'menuId',
																									this.menuId);
			var templateOptions = $.extend({}, (this.jsonMenu || this), prefix);
			this.template = $.tmpl(template, templateOptions);
			this.template.find('.attached_file').hide();
			this.template.find('.recorded-message').hide();
		},
		hideAddMenuLink: function () {
			$(this.options).each(function (i, option) { option.hideAddMenuLink(); });
		},
		nextMenuIdAvailable: function () {
			if (!this.menusList.size()) { return 0; }
			return ($.map(this.menusList, function (menu, index) { 
				if(menu != undefined){
						return menu.menuId;
					}
				}).max() + 1);
		},
		// Menu Relations
		jsonFix: function () {
			var self = this;
			JSON.stringify = function (value) {
				var array_tojson = Array.prototype.toJSON, r;
				delete Array.prototype.toJSON;
				r  = self.json_stringify(value);
				Array.prototype.toJSON = array_tojson;
				return r;
			};
		},
		resetJsonFix: function () {
			JSON.stringify = this.json_stringify;
		},
		syncRelations: function () {
			this.jsonFix();
			$('[rel=menu_relations]').val(JSON.stringify(this.relations));
			this.resetJsonFix();
		},
		addRelations: function () {
			if (this.menuId === 0) { return this.syncRelations(); } // Root Menu
			this.relations[0].push(this.menuId);
			this.syncRelations();
		},
		removeRelations: function () {
			if (this.menuId === 0) { return false; } // Root Menu
			this.relations[0].deleteElement(this.menuId);
			this.syncRelations();
		},
		// Menu Relations
		bindToThisMenu: function () {
			this.bindDelete();
			this.bindAddOption();
			this.bindRenameAndDone();
			this.$menuContainer.messageSelector({
				recordingUrl : (this.jsonMenu || {}).recordingUrl,
				attachmentName : (this.jsonMenu || {}).attachmentName,
				attachmentId: (this.jsonMenu || {}).attachmentId,
				attachmentUrl: (this.jsonMenu || {}).attachmentUrl,
				attachementDeleteCallback: this.handleAttachmentsDelete,
				attachementDeleteCallbackContext: this
			});
		},
		bindDelete: function () {
			var self = this;
			this.$dom.find('.close-btn').click(function () {
				if (confirm("Are you sure you want to delete " + self.realWorldName)) {
					self.deleteObject();
				}
			});
		},
		bindAddOption: function () {
			var self = this;
			this.$addOptionElement.click(function () {
				var opt = new IvrOption(self.ivr, self).build();

				if (self.options.length === Ivr.globalkeyslist.size()) {
					self.$addOptionElement.hide();
				}
			});
		},
		bindRenameAndDone: function () {
			this.bindEnter();
			this.bindRename();
			this.bindDone();
		},
		bindEnter:function () {
			var self = this;
			this.$title_input.bind('keydown', function (ev) {
				if(ev.keyCode == 13) {
					ev.preventDefault();
					ev.stopPropagation();
					self.changeName();
				}
			});
		},
		bindRename: function () {
			var self = this;
			this.$rename_link.click(function (ev) {
				ev.preventDefault();
				$(this).hide();
				self.$title_input.removeAttr('readonly').removeClass('readonly').focus();
				self.$done_rename_link.show();
			});
		},
		bindDone: function () {
			var self = this;
			this.$done_rename_link.click(function (ev) {
				ev.preventDefault();
				self.changeName();
			});
		},
		changeName: function () {
			this.$done_rename_link.hide();
			this.$title_input.attr('readonly', 'readonly').addClass('readonly');
			this.$rename_link.show();
			if (this.$title_input.val().blank()) {
				this.$title_input.val(this.menuName);
			} else {
				this.menuName = this.$title_input.val();
				this.$title_input.attr('title', this.menuName);
				this.ivr.propagateNameChange(this.menuId, this.menuName);
			}
		},
		propagateNameChange: function (menuId, menuName) {
			this.options.each(function (option, i) { option.propagateMenuNameChange(menuId, menuName); });
		},
		refreshAssignedRespondToOption: function () {
			var self = this;
			this.options.each(function (option, i) { option.refreshAssignedKey(self.assignedKeys); });
		},
		
		addMenuToList: function (menuId, menuName) {
			this.options.each(function (option, i) { option.addMenuToList(menuId, menuName); });
		},
		removeMenuFromList: function (menuId) {
			this.options.each(function (option, i) { option.removeMenuFromList(menuId); });
			this.menusList.deleteElement(this);
		},
		deleteObject: function () {
			if (!this.menuId) { return false; }
			this.removeDependantOptions();
			this.removeMenuFromList(this.menuId);
			this.removeRelations();
			this.hideAndDeleteMenu();
			delete globalmenus[this.menuId];
		},
		removeDependantOptions: function () {
			this.options.each(function (v, i) {
				v.deleteObject();
			});
		},
		hideAndDeleteMenu: function () {
			var twipsy = this.$dom.find('.close-btn').data('twipsy');
			this.$menuContainer.hide('fast', function () {
				if (twipsy) { twipsy.$tip.remove(); }
				this.remove();
			});
		},
		// Keypress manipulations
		findAvailableKeypress: function () {
			var self = this;
			return $.grep(Ivr.globalkeyslist, function (element) {
				return $.inArray(element, self.assignedKeys) === -1;
			})[0];
		},
		addKeypress: function (key) {
			this.assignedKeys.push(key);
			this.refreshAssignedRespondToOption();
		},
		changeRespondToKey: function (oldVal, newVal) {
			this.assignedKeys
				.splice(this.assignedKeys.indexOf(oldVal), 1, newVal);
			this.refreshAssignedRespondToOption();
		},
		removeRespondToKey: function (key) {
			this.assignedKeys.deleteElement(key);
			this.refreshAssignedRespondToOption();
		},
		isKeyAvailable: function (key) {
			return $.inArray(key, self.assignedKeys) === -1;
		},
		// Keypress manipulations
		addOption: function (option) {
			this.options.push(option);
		},
		menusCount: function () {
			return this.menusList.length;
		},
		removeOption: function (option) {
			this.options.splice(this.assignedKeys.indexOf(option), 1);
			if (this.$addOptionElement.is(':hidden')) {
				this.$addOptionElement.show('fast');
			}
		},
		handleAttachmentsDelete: function (id) {
		}
	};
	
	function replacePrefix(source, replaceText, replaceWith) {
		var replaceFiller = new RegExp('\\$\\{' + replaceText + '\\}');
		source = $.extend({}, source); // clone
		for(var prefix in source) {
			source[prefix] = source[prefix].replace(replaceFiller, replaceWith);
		}
		return source;
	}
	IvrMenu.prototype.relations = { 0 : []};
	IvrMenu.prototype.menusList = [];
}(jQuery));
