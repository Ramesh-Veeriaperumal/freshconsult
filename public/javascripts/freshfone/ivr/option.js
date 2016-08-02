var IvrOption;
(function ($) {
	"use strict";
	IvrOption = function (ivr, menu, jsonOption) {
		this.realWorldName = "Option";
		this.ivr = ivr;
		this.menu = menu;
		this.menuId = menu.menuId;
		this.$menuContainer = menu.$menuContainer;
		this.optionId = menu.nextOptionId++;

		if (jsonOption) { jsonOption.optionId = this.optionId; }
		this.jsonOption = jsonOption;		
	};
	
	IvrOption.prototype = {
		init: function () {
			this.$dom = this.$menuContainer.find('fieldset:last');
			this.$addToMenuLink = this.$dom.find('[rel=createMenu]').hide();
			this.$menuList = this.$dom.find('select[rel=IVR]');
			this.$deleteSymbol = this.$dom.find('.delete-symbol');
			this.$selectPerformer = this.$dom.find('[rel=performer]');
			this.$keypressContainer = this.$dom.find('.options-keypad');
			this.$keypressDropdown = this.$keypressContainer.find('select');
			this.$performerContainer = this.$dom.find('.performer-container');
			this.$actionPerformer = this.$performerContainer.find('.action_performer_container');
	
		},
		build: function () {
			if (this.availableKeypress() === undefined) { return false; }
			this.createDom();
			this.setRespondToKey();
			this.bindToThisOption();
			this.onLoadActions();
			return this;
		},
		createDom: function () {
			// template
			var template = $('#optionTemplate').clone(true, true);
			template.find('div.select2-container').remove(); // remove precreated select2
			this.message = "This is menu " + this.menuId + " keypress " + this.respondToKey;
			this.template = template.tmpl(this.jsonOption || this);
			this.removeInappropriatePerformers();
			this.$menuContainer.find('fieldset:last').after(this.template);
			this.menu.addOption(this);
			this.init();
		},
		bindToThisOption: function () {
			this.bindPerformerChange();
			this.bindRespondToKeySelection();
			this.bindDelete();
			this.bindMenuCreation();
			this.bindEmptyJumpTo();
		},
		bindPerformerChange: function () {
			var self = this;
			this.$selectPerformer.change(function (ev) {
				self.changeActivePerformer();
			});
		},
		bindDelete: function () {
			var self = this;
			this.$deleteSymbol.click(function () {
				self.deleteObject();
			});
		},
		bindMenuCreation: function () {
			var self = this;			
			this.$addToMenuLink.click(function () {
				self.ivr.menuCreation();
			});
		},
		bindEmptyJumpTo: function () {
			// change
			var self = this;
			this.$menuList.change(function () {
				if (!$(this).find('option').length) { self.showAddMenuLink(); }
			});
		},
		showAddMenuIfNeeded: function () {
			if (this.menu.menusCount() === 1) { this.showAddMenuLink(); }
		},
		showAddMenuLink: function () {
			this.$menuList.addClass('hide'); // Hack for some reason. Will update reason.
			var select2 = this.$menuList.data('select2');
			if (select2) { select2.container.hide(); }
			this.$addToMenuLink.show();
		},
		hideAddMenuLink: function () {
			this.$addToMenuLink.hide();
			var select2 = this.$menuList.removeClass('hide').data('select2');
			if (select2) {
				select2.container.show();
				var defaultMenuList = this.$menuList.find('option:first').val();
				this.$menuList.val(defaultMenuList).change(); // Set default
			}
		},
		onLoadActions: function () {
			this.showAddMenuIfNeeded();
			this.choosePerformerType();
			this.changeActivePerformer();
		},
		propagateMenuNameChange: function (menuId, menuName) {
			this.$menuList.find('option[value="' + menuId + '"]').text(menuName).change();
		},
		// Keypress related code
		// Checks for available keypress
		availableKeypress: function () {
			return this.respondToKey = (this.jsonOption !== undefined) ? this.jsonOption.respondToKey : this.menu.findAvailableKeypress();
		},
		setRespondToKey: function () {
			this.selectRespondToKey();
			this.menu.addKeypress(this.respondToKey);
		},
		selectRespondToKey: function () {
			this.$keypressDropdown.find('option[value="' + this.respondToKey + '"]')
				.attr('selected', 'selected');
			this.$keypressDropdown.data('currentValue', this.respondToKey);
		},
		changeRespondToKey: function (oldVal, newVal) {
			this.menu.changeRespondToKey(oldVal, newVal);
			this.respondToKey = newVal;
		},
		removeRespondToKey: function () {
			this.menu.removeRespondToKey(this.respondToKey);
		},
		bindRespondToKeySelection: function () {
			var self = this;
			this.$keypressDropdown.change(function (ev) {
				if (self.menu.isKeyAvailable($(this).val())) {
					self.changeRespondToKey($(this).data('currentValue'), $(this).val());
					$(this).data('currentValue', $(this).val());
				} else {
					$(this).val($(this).data('currentValue'));
				}
			});
		},
		// Keypress related code
		// Not-root menu should not have 'Jump To' option and its corresponding value
		// and 'Add New Menu' link
		// Root menu should not have 'Back To Main Menu' option
		removeInappropriatePerformers: function () {
			if (this.menuId) {
				this.template.find('option[value=IVR], [rel=IVR], [rel=createMenu]').remove();
			} else {
				this.template.find('option[value=Back], [rel=Back]').remove();
			}
		},
		choosePerformerType: function (menu) {
			if (this.jsonOption === undefined) { return false; }
			this.$dom.find('select').each(function () {
				if ($(this).data('selected') == '') { return false; }
				$(this).find('option[value=' + $(this).data('selected') + ']').attr('selected', true);
			});
		},
		changeActivePerformer: function () {
			var performerType = this.$selectPerformer.val();

			this.disableInactivePerformers(performerType);
			this.enableActivePerformer(performerType);
		},
		disableInactivePerformers: function (performerType) {
			var self = this;
			this.$actionPerformer
				.filter(':not(.' + performerType.toLowerCase() + '_performer)').each(function () {
					var $performerContainer = $(this);
					self.togglePerformerContainer($performerContainer, false);
			});
		},
		enableActivePerformer: function (performerType) {
			var $performerContainer = this.$actionPerformer.filter('.' + performerType.toLowerCase() + '_performer');
			this.togglePerformerContainer($performerContainer, true);
		},
		togglePerformerContainer: function ($performerContainer, show) {
			$performerContainer.toggle(show);
			$performerContainer.find('select.select2').each(function () {
				$(this).prop('disabled', !show);
				var select2 = $(this).data('select2');
				if (select2) { show ? select2.enable() : select2.disable(); }
			});
			$performerContainer.find('input.action_performer').prop('disabled', !show);
		},
		// Pseudo Destructor
		deleteObject: function () {
			var self = this;
			this.$dom.hide('fast', function () {
				self.removeRespondToKey();
				self.menu.removeOption(self);
				this.remove();
			});
		},
		addMenuToList: function (menuId, menuName) {
			this.$menuList.append($('<option />', { value : menuId, html : menuName }));
		},
		removeMenuFromList: function (menuId) {
			this.$menuList.find('option[value=' + menuId + ']').remove();
			this.$menuList.change();
		},
		refreshAssignedKey: function (keys) {
			var self = this;
			this.$keypressContainer.find('option[disabled]').removeAttr('disabled', 'disabled');
			keys.each(function (key) {
				self.$keypressContainer.find('option[value="' + key + '"]').each(function () {
					if ($(this).attr('selected') === undefined) {
						$(this).attr('disabled', 'disabled');
					}
				});
			});
		}
	};

}(jQuery));