/*jslint browser: true */
/*jslint devel: true */
/*jslint nomen: true */

/*global Mousetrap, Fjax, TICKET_DETAILS_DATA, closeCurrentTicket, Shortcuts,
        add_watcher, jQuery, helpdesk_submit, _preventDefault*/

(function ($) {
    'use strict';
    
    var _selectedListItemClass = 'sc-item-selected',
        // Prevent Browser Default Behaviour
        _preventDefault = function (ev) {
            if (ev.preventDefault) {
                ev.preventDefault();
            }
            // for IE 8 & below
            ev.returnValue = false;
        },
        overrideMozQuickSearch = function (ev) {
            var tagName = document.activeElement.tagName,
                isContentEditable = document.activeElement.isContentEditable,
                editableElm = ['INPUT', 'SELECT', 'TEXTAREA'];

            if (ev.which === 0 || editableElm.indexOf(tagName) != -1 || isContentEditable) {
                // Dont prevent (up,down,left,right) keys default
                return;
            } else if (!ev.metaKey) { // Dont prevent mozilla default Shortcuts
                ev.preventDefault();
            }
        },
        // Prevent key action from multiple times firing with interval of 1 second
        //@return Boolean
        preventMultiple = function (el) {
            var stopFire = $(el).data('prevent-event-fire');
            if (stopFire) {
                return stopFire;
            } else {
                $(el).data('prevent-event-fire', true);
                setTimeout(function () { $(el).data('prevent-event-fire', false); }, 1000);
                return stopFire;
            }
        },
        _highlightElement = function (el) {
            // Hack for IE 8 && below version
            if (($.browser.msie) && (parseInt($.browser.version, 10) < 9)) {
                $(el).css('background-color', '#ffffff');
            }

            $(el).effect('highlight', {color: '#333333', easing: 'easeOutQuad'}, 800);
            setTimeout(function () { $(el).removeAttr('style'); }, 850);
        },
        tooltipForUnbindedElement = function(){
            $(this).each(function(){
                if($(this).hasClass('tooltip'))
                    setShortcutTooltip(this,$(this).data('hotkey'));
            })
        },
        setShortcutTooltip = function (el, bindedKey) {
            var _key = bindedKey.replace(/\s/, ' then '),
                _elmTitle = el.title || $(el).data('original-title');
                if(!$(el).data('real-title')){
                    $(el).data('real-title', _elmTitle)
                        .attr('title', _elmTitle + ' ( ' + _key + ' )');
                }
        },
        // This will bind keys for elements which has attribute 'data-keybinding'
        doKeyBindingfor = function () {
            $(this).each(function (i, el) {
                var keys = $(el).data('keybinding'),
                    bindedKey = (typeof keys === 'number') ? keys.toString() : keys,
                    elmType = el.type || el.nodeName,
                    _event = (elmType === 'text') ? 'focus' : 'click',
                    highlight = $(el).data('highlight');

                Mousetrap.bind(bindedKey, function (e) {

                    var isDisabled = el.hasAttribute('disabled') || $(el).hasClass('disabled');
                    
                    _preventDefault(e);
                    if (!isDisabled && !preventMultiple(el)) {
                        if (highlight) { _highlightElement(el); }
                        el[_event]();
                    }
                });

                if ($(el).hasClass('tooltip')) { setShortcutTooltip(el, bindedKey); }
            });
        },
        // -----------  Global Shortcuts  ----------------
        shortcutHelp = function (ev) {
            _preventDefault(ev);
            // check if any modal has opened 
            if($('.modal:visible').length == 0 || $('.modal:visible').attr('id') == 'help_chart'){
                // close qtip if any opened on viewing help chart
                // work around need to fix properly
                $('.qtip:visible').qtip('hide');

                var isVisible = $('#help_chart').is(':visible'),
                    _selector = isVisible ? '#help_chart button.close' : '#shortcut_help_chart';

                $(_selector).trigger('click');
            }
        },
        save = function (ev) {
            _preventDefault(ev);
            var currentActiveForm = $('body').data('current-active-form');

            if (currentActiveForm && $(currentActiveForm).is(":visible")) {
                $(currentActiveForm).trigger('submit');
                $('body').removeData('current-active-form');
            }

            return;
        },
        cancel = function (ev) {
            if($( ".request_panel .dropdown-menu:visible").get(0)){
                var id = getConversationId();
                $('#' + id + ' .dialog-btn').trigger("click");
                $('#' + id + ' .dialog-btn').blur();
            }else if($('.modal:visible').get(0)){
                $('.modal:visible').modal('hide');
            }else if($('#redactor_modal:visible').get(0)){
                $('#redactor_modal').modal('hide');
                $('redactor_modal_overlay').hide();
            }else if($('#new_watcher_page:visible').get(0)){ 
                 $(".watcher-close").trigger('click');
            }else if($('.blockUI:visible').get(0)){
            }else if ($('.sol-sticky #sticky_search_wrap').is(':visible')) {
                App.Solutions.SearchConfig.hideSearch();
            }else{ 
                $(".watcher-close").trigger('click');    
                document.getElementById('header_search').value = '';
                document.activeElement.blur();
                $('.qtip:visible').qtip('hide');
                $('.cancel_btn:visible').trigger('click');
                $('.twipsy:visible').trigger('hide');
                $('#help_chart').modal('hide');
            }
            Mousetrap.unpause();
        },
        // ------------  Ticket List  ----------------------
        showSelectedTicket = function (ev) {
            _preventDefault(ev);
            $('.' + _selectedListItemClass + ' .ticket_subject a').get(0).click();
        },
        toggleTicketDescription = function (ev) {
            _preventDefault(ev);
            if ($('#ui-tooltip-' + $('.' + _selectedListItemClass).data('ticket')).is(':visible')) {
                $('.' + _selectedListItemClass + ' .ticket_subject').find('.ticket-description-tip').qtip('hide');
            } else {
                $('.' + _selectedListItemClass + ' .ticket_subject').find('a').first().trigger('mouseover');
            }

            autoScroll($('.' + _selectedListItemClass));
        },
        selectTicket = function () {
            $('tr.' + _selectedListItemClass + ' input.selector').trigger('click').trigger('change');
        },
        initScrollTo = function (el) {
            $(document).scrollTop(el.offset().top);
            //$.scrollTo(el).scrollTo.window().queue([]).stop();
        },
        autoScroll = function (el, percentToScroll) {
            var docTop = $(document).scrollTop(),
                itemSltrTop = el.offset().top,
                itemSltrBotm = itemSltrTop + el.height(),
                frame = $(window).height() + docTop,
                percent = percentToScroll || 50,
                scrollTo = Math.floor($(window).height() * percent / 100);

            if (itemSltrBotm <= docTop || itemSltrTop >= frame) {
                initScrollTo(el);
            } else if (itemSltrBotm >= frame) {
                $(document).scrollTop((docTop + scrollTo));
            } else if (itemSltrTop <= docTop) {
                $(document).scrollTop((docTop - scrollTo));
            }
        },
        selectedTicketReply = function(ev,key) {
            var href = $('.' + _selectedListItemClass + ' .ticket_subject a').attr('href');
                href += "#"+key;
            $('.' + _selectedListItemClass + ' .ticket_subject a').attr('href', href);
            showSelectedTicket(ev);
        },        
        // ----------  Ticket Detail view  -------------
        toggleWatcher = function (ev) {
            _preventDefault(ev);
            var $el = $('#watcher_toggle'),
                watching = $el.data('watching'),
                ticket_id = TICKET_DETAILS_DATA.displayId,
                cur_user = $el.data('currentuserid');

            if (watching) {
                $('.unwatch').trigger('click');
            } else {
                $('#ids').select2('val', cur_user);
                add_watcher();
            }

            _highlightElement($el.data('watching', !watching));
        },
        ticketProperties = function () {
            $('#TicketPropertiesFields select:first').data('select2').container.find('a').trigger('focus');
        },
        closeTicket = function (ev, key) {
            _preventDefault(ev);
            var closeBtn = document.getElementById('close_ticket_btn'),
                silent_close = (key === 'silent_close');

            if (!closeBtn.disabled)  _highlightElement(closeBtn);

            if (Fjax.current_page === 'ticket_list' && closeBtn && !closeBtn.disabled) {
                helpdesk_submit('/helpdesk/tickets/multiple/close_multiple',
                    'put', [{ name: 'disable_notification',
                                value: silent_close
                            }]);
            } else if (Fjax.current_page === 'ticket_detail' && closeBtn) {
                closeCurrentTicket({shiftKey: silent_close});
            }
        },
        expand = function () {
            $('#show_more:visible').trigger('click');
        },
        /* the following are for Social Streams */
        socialOpenStream = function(e){
            console.log('socialOpenStream triggered ');
            $('.twt-list-item.selected-tweet').trigger("click");
            _preventDefault(e);
        },
        socialReply = function(e){
            console.log('socialReply triggered ');
            _preventDefault(e);
            
            $('.selected-tweet').find('.sharer_reply_button').trigger("click");
            
        },
        socialRetweet = function(e){
            console.log('socialRetweet triggered ');
            _preventDefault(e);
            $('.selected-tweet').find('.sharer_retweet_button').trigger("click");
        },
        socialStreamClose = function(e){
            $('.conv-closebtn').trigger("click");
        },
        socialFocusOnSearchInput = function(e){
            $('.tw-search ul li input').focus();
            _preventDefault(e);
        },
        ticketStatusDialog = function(){
            if(!$('.blockUI:visible').get(0)){
                var id = getConversationId();
                $('#' + id + ' .dialog-btn').trigger("click");
            }
        },
        selectWatcher = function(ev){
            _preventDefault(ev);
            $("#watcher_toggle a").trigger('click');
            $("#addwatcher .select2-search-field input").focus();
        },
        getConversationId = function(){
            return $('.conversation_thread form:visible').attr('id');
        },
        saveAndPreview = function(ev,key){
            var value = (key == "save_cuctomization") ? 'save_button' : 'preview_button'
            $('input[name="'+ value +'"]:visible')[0].click();
        },

        // --------------- Forum pages -------------------//
        toggleForumFollower = function (ev, key) {
            App.Discussions.Monitorship.toggleForCurrentUser();
        },

        addForumFollower = function (ev, key) {
            App.Discussions.Monitorship.showAddFollower();
        },

        KB = {
            global        : {
                help                : shortcutHelp,
                save                : save,
                cancel              : cancel,
                status_dialog       : ticketStatusDialog,
                save_cuctomization  : saveAndPreview
            },
            ticket_list   : {
                ticket_show         : showSelectedTicket,
                select              : selectTicket,
                show_description    : toggleTicketDescription,
                close               : closeTicket,
                silent_close        : closeTicket,
                reply               : selectedTicketReply,
                forward             : selectedTicketReply,
                add_note            : selectedTicketReply
            },
            ticket_detail : {
                toggle_watcher      : toggleWatcher,
                properties          : ticketProperties,
                close               : closeTicket,
                silent_close        : closeTicket,
                expand              : expand,
                select_watcher      : selectWatcher              
            },
            social_stream   : {
                open_stream         : socialOpenStream,
                reply               : socialReply,
                retweet             : socialRetweet,
                close               : socialStreamClose,
                search              : socialFocusOnSearchInput
            },
            portal_customizations : {
                preview             : saveAndPreview
            },
            discussions     : {
                toggle_following    : toggleForumFollower,
                add_follower        : addForumFollower
            }
        },
        // Take care of binding all namespaced callback functions of KB object
        bindKeys = function (namespace, isGlobal) {
            isGlobal = isGlobal || false;
            $.each(KB[namespace], function (key) {
                var _method = (isGlobal && key !== 'help') ? 'bindGlobal' : 'bind';
                Mousetrap[_method](Shortcuts[namespace][key], function (ev) { KB[namespace][key](ev, key); });
            });
        },
        dispatcher = function () {
            bindKeys('global', true);
            if (Fjax.current_page !== null && KB[Fjax.current_page]) {
                bindKeys(Fjax.current_page);
            }
        }

        var KeyboardShortcuts = function(shortcuts_data){

            var $self = this;

            $self.reset();

            // Delegating keyboard shortcuts and view level cleanup
            $('body')
                .addClass('shortcuts-active')
                .on('focusin.keyboard_shortcuts', 'form', function (e) {
                    // Get current active form
                    $('body').data('current-active-form', this);
                })
                .on('change.keyboard_shortcuts', function (e) {
                    // Hide twipsy on body change
                    $('.twipsy:visible').hide();
                })
                .on('shown.keyboard_shortcuts hidden.keyboard_shortcuts', '.modal', function (e) {
                    // Pause / resume keyboard shortcut on help chart toggle
                    var _switch = (e.type === 'shown') ? 'pause' : 'unpause';
                    Mousetrap[_switch]();
                    $('#ticket-list').menuSelector(_switch)
                });
            
            // Binding keyboard reset for pjax
            $(document)
                .on('pjax:complete.keyboard_shortcuts', function() { $(document).off("keydown.menuSelector"); $self.reset();})
            
            // To prevent Mozilla's "search for text when i start typing" pref option
            // if ($.browser.mozilla) {
            //     $('body').on('keypress.moz', overrideMozQuickSearch)
            // }
        }

        KeyboardShortcuts.prototype = {
            constructor: KeyboardShortcuts,
            reset: function(){
                // Reset existing shortcuts
                Mousetrap.reset();

                // Dispatch shortcut events of current page to the event binder (bindKeys)
                // can also define event bind type (global/single)
                dispatcher();

                // Bind event for elements which has attr ['data-keybinding']
                $('[data-keybinding]').livequery(doKeyBindingfor);

                //Bind shortcut key for un-keybinding tooltip
                $('[data-hotkey]').livequery(tooltipForUnbindedElement);

                $('#ticket-list').menuSelector({
                        activeClass: 'sc-item-selected',
                        onHoverActive:false,
                        scrollInDocument:true,
                        additionUpKeys:75, // key k : 75
                        additionDownKeys:74 // key j : 74
                })
            },
            destroy: function(){
                Mousetrap.reset();

                $('[data-keybinding]').expire();

                $('body')
                    .off('.keyboard_shortcuts')
                    .removeClass('shortcuts-active');

                $(document)
                    .off('pjax:complete.keyboard_shortcuts');

                //Remove all shortcut key hint from tooltip
                this.resetShortcutTooltip();

                $('#ticket-list').menuSelector('destroy');
            },
            setListItemCursor: function(class_name) {
                $('#ticket-list').menuSelector('reset');
                if(!$('.' + _selectedListItemClass).get(0))
                    $(class_name).first().addClass(_selectedListItemClass);
            },
            resetShortcutTooltip: function () {
                $('[data-keybinding],[data-hotkey]').each(function(){
                    if($(this).hasClass('tooltip'))
                        $(this).attr('title', $(this).data('real-title')).removeData('real-title');
                });
            }
        };

    $(document)
        .on("shortcuts:invoke", function(ev){
            // Pass params through ev when invoking from any page
            ev.shortcuts_data = ev.shortcuts_data || {};

            window.shortcuts = new KeyboardShortcuts(ev.shortcuts_data);
        })
        .on("shortcuts:destroy", function(ev){
            if(window.shortcuts || window.shortcuts != null){
                // Call the destroy hook for shortcuts
                window.shortcuts.destroy();

                // Remove traces of shortcuts
                window.shortcuts = null
            }
        })        
        .ready(function(){ 
        	$(document).trigger("shortcuts:invoke"); 
        });

}(jQuery));