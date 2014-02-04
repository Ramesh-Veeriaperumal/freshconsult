/*jslint browser: true */
/*jslint devel: true */
/*jslint nomen: true */

/*global Mousetrap, Fjax, TICKET_DETAILS_DATA, closeCurrentTicket, Shortcuts,
        add_watcher, jQuery, helpdesk_submit, _preventDefault*/

(function ($) {
    'use strict';
    
    var _selectedListItemClass = 'sc-item-selected',
        // Prevent Browser Default Behaviour
        _preventDefault = function (e) {
            if (e.preventDefault) {
                e.preventDefault();
            }
            // for IE 8 & below
            e.returnValue = false;
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
                    var isDisabled = $(el).hasAttr('disabled') || $(el).hasClass('disabled');
                    
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
            var isVisible = $('#help_chart').is(':visible'),
                _selector = isVisible ? '#help_chart button.close' : '#shortcut_help_chart';

            $(_selector).trigger('click');
        },
        save = function (ev) {
            _preventDefault(ev);
            var currentActiveForm = $('body').data('current-active-form');

            if (currentActiveForm) {
                $(currentActiveForm).trigger('submit');
                $('body').removeData('current-active-form');
            }

            return;
        },
        cancel = function () {
            $('.modal:visible').modal('hide');
            document.getElementById('header_search').value = '';
            document.activeElement.blur();
            $('.qtip:visible').qtip('hide');
            $('.twipsy:visible').trigger('hide');
            $('.cancel_btn:visible').trigger('click');
            $('#help_chart').modal('hide');
            Mousetrap.unpause();
        },
        // ------------  Ticket List  ----------------------
        showSelectedTicket = function (ev) {
            _preventDefault(ev);
            var el = $('.' + _selectedListItemClass + ' .ticket_subject a').get(0).click();
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
        initScrollToSelected = function (el) {
            $.scrollTo(el);
        },
        autoScroll = function (el, percentToScroll) {
            var docTop = $(document).scrollTop(),
                itemSltrTop = el.offset().top,
                itemSltrBotm = itemSltrTop + el.height(),
                frame = $(window).height() + docTop,
                scrollTo = $(window).height() * percentToScroll / 100;

            if (itemSltrBotm <= docTop || itemSltrTop >= frame) {
                initScrollToSelected(el);
            } else if (itemSltrBotm >= frame) {
                $('html').animate({scrollTop : (docTop + scrollTo) + 'px'}, 500, 'easeOutQuad');
            } else if (itemSltrTop <= docTop) {
                $('html').animate({scrollTop : (docTop - scrollTo) + 'px'}, 500, 'easeOutQuad');
            }
        },
        moveItemSelector = function (ev, key) {
            var $el = $("tr." + _selectedListItemClass),
                _method = (key === "go_to_previous") ? 'prev' : 'next';

            if ($el && $el[_method]().length !== 0) {
                _preventDefault(ev);
                var $other_el = $el[_method]();
                $other_el.addClass(_selectedListItemClass);
                $el.removeClass(_selectedListItemClass).addClass('fade-out');
                setTimeout(function(){ $el.removeClass('fade-out'); }, 250);
                
                autoScroll($other_el, 50);  // params : (movable element to trace, percent to scroll)
            }
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

            _highlightElement(closeBtn);

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
        KB = {
            global        : {
                help                : shortcutHelp,
                save                : save,
                cancel              : cancel
            },
            ticket_list   : {
                ticket_show         : showSelectedTicket,
                select              : selectTicket,
                show_description    : toggleTicketDescription,
                go_to_next          : moveItemSelector,
                go_to_previous      : moveItemSelector,
                close               : closeTicket,
                silent_close        : closeTicket
            },
            ticket_detail : {
                toggle_watcher      : toggleWatcher,
                properties          : ticketProperties,
                close               : closeTicket,
                silent_close        : closeTicket,
                expand              : expand
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
                .on('shown.keyboard_shortcuts hidden.keyboard_shortcuts', '#help_chart', function (e) {
                    // Pause / resume keyboard shortcut on help chart toggle
                    var _switch = (e.type === 'shown') ? 'pause' : 'unpause';
                    Mousetrap[_switch]();
                });
            
            // Binding keyboard reset for pjax
            $(document).on('pjax:complete.keyboard_shortcuts', function() { $self.reset(); })
        }

        KeyboardShortcuts.prototype = {
            constructor: KeyboardShortcuts,
            reset: function(){
                console.log('Shortcuts reset');
                // Reset existing shortcuts
                Mousetrap.reset();

                // Dispatch shortcut events of current page to the event binder (bindKeys)
                // can also define event bind type (global/single)
                dispatcher();

                // Bind event for elements which has attr ['data-keybinding']
                $('[data-keybinding]').livequery(doKeyBindingfor);

                // Loading item selection for tickets table view
                this.setListItemCursor("table.tickets tbody tr");
            },
            destroy: function(){
                console.log('shortcuts destroyed')
                Mousetrap.reset();

                $('[data-keybinding]').expire();

                $('body')
                    .off('.keyboard_shortcuts')
                    .removeClass('shortcuts-active');

                $(document).off('pjax:complete.keyboard_shortcuts')

                //Remove all shortcut key hint from tooltip
                this.resetShortcutTooltip();
            },
            setListItemCursor: function(class_name) {
                console.log("SET LIST")
                if(!$('.' + _selectedListItemClass).get(0))
                    $(class_name).first().addClass(_selectedListItemClass);
            },
            resetShortcutTooltip: function () {
                $('[data-keybinding]').each(function(){
                    if($(this).hasClass('tooltip'))
                        $(this).attr('title', $(this).data('real-title')).removeData('real-title');
                });
            }
        };

    $(document)
        .on("shortcuts:invoke", function(ev){
            console.log('shortcuts : invoked')
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
        .ready(function(){ $(document).trigger("shortcuts:invoke") })

}(jQuery));