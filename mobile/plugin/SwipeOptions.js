Ext.define('ux.SwipeOptions', {
    extend: 'Ext.Component',
    alias: 'swipeOptions',
    requires: ['Ext.Anim'],
    config: {

        /**
         * Selector to use to get the dynamically created List Options Ext.Element (where the menu options are held)
         * Once created the List Options element will be used again and again.
         */
        optionsSelector: 'x-list-options',

        /**
         * An array of objects to be applied to the 'listOptionsTpl' to create the 
         * menu
         */
        menuOptions: [],
        
        /**
         * Selector to use to get individual List Options within the created Ext.Element
         * This is used when attaching event handlers to the menu options
         */
        menuOptionSelector: 'x-menu-option',
        
        /**
         * XTemplate to use to create the List Options view
         */
        menuOptionsTpl: new Ext.XTemplate(  '<ul>',
                                                '<tpl for=".">',                                            
                                                    '<li class="x-menu-option {cls}">',
                                                    '</li>',
                                                '</tpl>',
                                            '</ul>').compile(),
                                    
        /**
         * CSS Class that is applied to the tapped Menu Option while it is being touched
         */     
        menuOptionPressedClass: 'x-menu-option-pressed',
        
        /**
         * Set to a function that takes in 2 arguments - your initial 'menuOptions' config option and the current 
         * item's Model instance
         * The function must return either the original 'menuOptions' variable or a revised one
         */
        menuOptionDataFilter: null,
        
        /**
         * Animation used to reveal the List Options
         */
        revealAnimation: {
            reverse: false,
            type: 'slide',
            duration: 500
        },
        
        /**
         * The direction the List Item will slide to reveal the List Options
         * Possible values: 'left', 'right' and 'both'
         * setting to 'both' means it will be decided by the direction of the User's swipe if 'triggerEvent' is set to 'itemswipe'
         */
        revealDirection: 'both',
        
        /**
         * Distance (in pixels) a User must swipe before triggering the List Options to be displayed.
         * Set to -1 to disable threshold checks
         */
        swipeThreshold: 30,
        
        /**
         * The direction the user must swipe to reveal the menu
         * Only applicable when 'triggerEvent' is set to 'itemswipe'
         */
        swipeDirection: 'both',
        
        /**
         * Decides whether multiple List Options can be visible at once
         */
        allowMultiple: false,
        
        /**
         * Decides whether sound effects are played as List Options open
         * Defaults to false.
         */
        enableSoundEffects: false,
        
        openSoundEffectURL: 'sounds/open.wav',
        
        closeSoundEffectURL: 'sounds/close.wav',

        /**
        * Decides whether to stop scroll for list on list options visible
        * Defaults to false
        */
        stopScrollOnShow : false
    
    },

    initialize: function() {
        this.callParent();
    },

    init: function(list) {
        var self = this;
        self.list = list;
        list.on('itemswipe',self.onItemSwipe,self);
    },

    onItemSwipe : function(list, index, target, record, evt, options , eOpts){
        // check we're over the 'swipethreshold'
        if(this.revealAllowed(evt)){
            // set the direction of the reveal
            this.setRevealDir(evt.direction);

            // cache the current List Item's elements for easy use later
            this.activeListItemRecord = list.getStore().getAt(index);
            
            var activeEl = Ext.get(target);

            this.activeListElement = activeEl;        
            
            activeEl.setVisibilityMode(Ext.Element.VISIBILITY);

            this.activeItemRecord = record;
            // Show the item's List Options
            this.doShowOptionsMenu(activeEl);
        }
    },

    /**
     * Decide whether the List Options are allowed to be revealed based on the config options
     * Only relevant for 'itemswipe' event because this event has all the config options
     * @param {Object} event
     */
    revealAllowed: function(evt){
        var direction = evt.direction,
            distance = evt.distance,
            allowed = false,
            swipeThreshold = this.getSwipeThreshold(),
            swipeDirection = this.getSwipeDirection();
        allowed =  (distance >= swipeThreshold && (direction === swipeDirection || swipeDirection === 'both')) || swipeThreshold < 0 ;
        return allowed;
    },

    /**
     * Decide the direction the reveal animation will go
     * this.revealDirection config can only be 'both' when triggerEvent is 'itemswipe' in which case
     * the direction of the swipe is used
     * @param {Object} direction
     */
    setRevealDir: function(direction){
        var dir = this.getRevealDirection(),
        revealAnimation = this.getRevealAnimation();
        if(dir === 'both'){
            dir = direction;
        }

        Ext.apply(revealAnimation, {
            direction: dir
        });
    },

    doHideOptionsMenu : function(hiddenEl, activeListOptions, playSoundEffect){
        playSoundEffect = Ext.isEmpty(playSoundEffect) ? true : playSoundEffect;
        
        var revealAnimation = this.getRevealAnimation(),
        enableSoundEffects = this.getEnableSoundEffects(),
        closeSoundEffectURL = this.getCloseSoundEffectURL();        
        
        activeListOptions.setVisibilityMode(Ext.Element.DISPLAY).hide();
        hiddenEl.show();
        // Run the animation on the List Item's 'body' Ext.Element
        Ext.Anim.run(hiddenEl, revealAnimation, {
            out: false,
            before: function(el, options){
                // force the List Options to the back
                activeListOptions.setStyle('z-index', '0');
                
                //Audio effect for close if configured
                if (enableSoundEffects && !Ext.isEmpty(closeSoundEffectURL) && playSoundEffect) {
                    var audio = document.createElement('audio');
                    audio.setAttribute('src', closeSoundEffectURL);
                    audio.play();
                }
            },
            after: function(el, options){
                hiddenEl.setVisibilityMode(Ext.Element.DISPLAY);
                
                // remove the ListOptions DIV completely to save some resources
                // activeListOptions.remove();
                Ext.removeNode(Ext.getDom(activeListOptions));
                
                this.list.fireEvent('listoptionsclose');
            },
            scope: this
        });
    },

    /**
     * Perform the List Option animation and show
     * @param {Object} listItemEl - the List Item's element to show a menu for
     */
    doShowOptionsMenu: function(listItemEl){

        var stopScrollOnShow = this.getStopScrollOnShow(),
            revealAnimation = this.getRevealAnimation(),
            enableSoundEffects = this.getEnableSoundEffects(),
            openSoundEffectURL = this.getOpenSoundEffectURL();

        if(stopScrollOnShow){
            this.list.scroller.disable();
        }
        
        // ensure the animation is not reversed
        Ext.apply(revealAnimation, {
            reverse: false
        });
       
        // Do the animation on the current 
        Ext.Anim.run(listItemEl, revealAnimation, {
            out: true,
            before: function(el, options){
                // Firing beforeOptionsrender
                this.list.fireEvent('beforeOptionsrender',this,this.activeItemRecord);
                // Create the List Options Ext.Element
                this.createOptionsMenu(listItemEl);

                // Firing afterOptionsrender
                this.list.fireEvent('afterOptionsrender',this,this.activeItemRecord);
            },
            after: function(el, options){
                listItemEl.hide(); // hide the List Item

                //Audio effect if configured for show
                if (enableSoundEffects && !Ext.isEmpty(openSoundEffectURL)) {
                    var audio = document.createElement('audio');
                    audio.setAttribute('src', openSoundEffectURL);
                    audio.play();
                }

                this.list.fireEvent('listoptionsopen',this,this.activeItemRecord);
                
                this.activeListOptions.show();
                // re-enable the scroller
                if (stopScrollOnShow) {
                    this.list.scroller.enable();
                }
            },
            scope: this
        });
    },
    
    /**
     * Used to process the menuOptions data prior to applying it to the menuOptions template
     */
    processMenuOptionsData: function(){
        return (Ext.isFunction(this.getMenuOptionDataFilter())) ? this.getMenuOptionDataFilter(this.getMenuOptions(), this.activeListItemRecord) : this.getMenuOptions();
    },
    
    /**
     * Get the existing or create a new List Options Ext.Element and return and cache it
     * @param {Object} listItem
     */
    createOptionsMenu: function(listItemEl){
        var listItemElHeight = listItemEl.getHeight(),
        menuOptionsTpl = this.getMenuOptionsTpl(),
        optionsSelector = this.getOptionsSelector(),
        processMenuOptionsData = this.processMenuOptionsData(),
        menuOptionSelector = this.getMenuOptionSelector(),
        self=this;
        
        // Create the List Options element
        this.activeListOptions = Ext.DomHelper.insertAfter(listItemEl, {
            cls: optionsSelector,
            html: menuOptionsTpl.apply(processMenuOptionsData),
        }, true).setHeight(listItemElHeight);
        
        this.activeListOptions.setVisibilityMode(Ext.Element.VISIBILITY).hide();

        var optionListArr = this.activeListOptions.select('.' + menuOptionSelector).elements;
        for(var index in optionListArr) {
            Ext.get(optionListArr[index]).on({
                 touchstart: self.onListOptionTabStart,
                 touchend: self.onListOptionTapEnd,
                 tapcancel: self.onListOptionTabCancel,
                 scope:self
            });
        }

        // attach event handler to options element to close it when tapped
        (function(_activeListOptions,_activeListElement,self) {
            _activeListOptions.on({
                tap: function(evt){
                    // ensure the animation is  reversed
                    Ext.apply(self.getRevealAnimation(), {
                        reverse: true
                    });
                    self.doHideOptionsMenu.apply(self, [_activeListElement, _activeListOptions]);
                    evt.stopPropagation();
                    return false;
                },
                swipe : function(evt){
                    self.setRevealDir(evt.direction);
                    self.doHideOptionsMenu.apply(self, [_activeListElement, _activeListOptions]);
                    evt.stopPropagation();
                    return false;
                },
                scope: self
            });
        })(this.activeListOptions,this.activeListElement,this)

        return this.activeListOptions;
    },
    
    /**
     * Handler for 'touchstart' event to add the Pressed class
     * @param {Object} e
     * @param {Object} el
     */
    onListOptionTabStart: function(e, el){
        var menuOptionSelector = this.getMenuOptionSelector(),
            optionsSelector = this.getOptionsSelector(),
            menuOption = e.getTarget('.' + menuOptionSelector),
            listOptionsEl = Ext.get(Ext.get(menuOption).findParent('.' + optionsSelector)).prev('.x-list-item');
        
        // get the menu item's data
        var menuItemData = this.processMenuOptionsData()[this.getIndex(menuOption)];
        
        if (this.list.fireEvent('beforelistoptionstap', menuItemData, this.list.getRecord(listOptionsEl.dom)) === true) {
            this.addPressedClass(e);
        } else {
            this.TapCancelled = true;
        }
    },
    
    /**
     * Handler for 'tapcancel' event
     * Sets TapCancelled value to stop TapEnd function from executing and removes Pressed class
     * @param {Object} e
     * @param {Object} el
     */
    onListOptionTabCancel: function(e, el){
        this.TapCancelled = true;
        this.removePressedClass(e);
    },
    
    /**
     * Handler for the 'tap' event of the individual List Option menu items
     * @param {Object} e
     */
    onListOptionTapEnd: function(e, el){
        if (!this.TapCancelled) {
            // Remove the Pressed class
            this.removePressedClass(e);
            
            var menuOptionSelector = this.getMenuOptionSelector(),
                optionsSelector = this.getOptionsSelector(),
                menuOption = e.getTarget('.' + menuOptionSelector);
                // listOptionsEl = Ext.get(Ext.get(menuOption).findParent('.' + optionsSelector)).prev('.x-list-item',true);

            // get the menu item's data
            var menuItemData = this.processMenuOptionsData()[this.getIndex(menuOption)];
            this.list.fireEvent('menuoptiontap', menuItemData);
        }
        this.TapCancelled = false;
        
        // stop menu from hiding
        e.stopPropagation();
    },
    
    /**
     * Adds the Pressed class on the Menu Option
     * @param {Object} e
     */
    addPressedClass: function(e){
        var menuOptionSelector = this.getMenuOptionSelector(),
            menuOptionPressedClass = this.getMenuOptionPressedClass(),
            elm = e.getTarget('.' + menuOptionSelector);
        if (Ext.fly(elm)) {
            Ext.fly(elm).addCls(menuOptionPressedClass);
        }       
    },
    
    /**
     * Removes the Pressed class on the Menu Option
     * @param {Object} e
     */
    removePressedClass: function(e){
        var menuOptionSelector = this.getMenuOptionSelector(),
            menuOptionPressedClass = this.getMenuOptionPressedClass(),
            elm = e.getTarget('.' + menuOptionSelector);
        if (Ext.fly(elm)) {
            Ext.fly(elm).removeCls(menuOptionPressedClass);
        }       
    },
    
    /**
     * Helper method to get the index of the List Option that was tapped
     * @param {Object} el - the tapped node
     */
    getIndex: function(el){
        var optionsSelector = this.getOptionsSelector(),
            menuOptionSelector = this.getMenuOptionSelector(),
            listOptions = Ext.get(Ext.get(el).findParent('.' + optionsSelector)).select('.' + menuOptionSelector);
        
        for(var i = 0; i < listOptions.elements.length; i++){
            if(listOptions.elements[i].id === el.id){
                return i;
            }
        }
        return -1;
    }
});
