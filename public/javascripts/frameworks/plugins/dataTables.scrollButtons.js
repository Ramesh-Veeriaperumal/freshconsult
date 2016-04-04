/* 
*  
*  @purpose : Jquery Datatable Plugin to add scroll buttons to datatable.
*  @Datatable_version_supported : 1.10.9
*  @author  : Srihari
*  @usage :  
*  1. Include the js & associated css in the page.
*  2. In the Datatable Initialization, append 'S' to sdom attribute.
*  3. customizations available :
      a. scrollSpeed
      b. scrollDistance
      b. disableDraggableScroll
*/
(function(){
    jQuery.fn.dataTable.ext.feature.push({

    scroll_distance: 750, // px
    scroll_speed: 600, // Milliseconds
    disable_draggable_scroll: false,
    current_scroll_position: 0,
    max_scroll_left: 0,
    disable_class: 'disable',
    shadow_class: ['left-shadow', 'right-shadow'],

    fnInit: function(settings) {
        this._wrapper = settings.nTableWrapper;
        this.bind();
        this.scroll_distance = settings.oInit.scrollDistance ? parseInt(settings.oInit.scrollDistance) : this.scroll_distance;
        this.disable_draggable_scroll = settings.oInit.disableDraggableScroll ? settings.oInit.disableDraggableScroll : false;
        this.markup(settings);
    },
    bind: function() {

        var _this = this;
        //Bind events to buttons
        jQuery(this._wrapper).on("click", "[data-action='data-tab-nav']", function(event) {
            var source = jQuery(event.target); // Sometime source can be font tag inside button
            var attr = jQuery(source).attr('data-direction');
            var direction;

            if (attr !== undefined) {
                direction = jQuery(source).data('direction');
            } else {
                source = jQuery(event.target.parentElement);
                direction = jQuery(source).data('direction');
            }

            if (!jQuery(source).hasClass(this.disable_class)) {
                if (direction == 'previous') {
                    _this.scrollLeft();
                } else {
                    _this.scrollRight();
                }
            }

        })
    },
    scrollLeft: function() {

        if (this.current_scroll_position != 0) {
            var move_x = this.current_scroll_position - this.scroll_distance;
            if (move_x < 0) {
                this.current_scroll_position = 0;
            } else {
                this.current_scroll_position = move_x;
            }
        }
        this.translateTable();
    },
    scrollRight: function() {

        this.queryDom();
        this.calculateMaxScroll();
        //console.log(this.current_scroll_position + " " + this.scroll_distance);
        if (this.current_scroll_position != this.max_scroll_left) {
            var move_x = this.current_scroll_position + this.scroll_distance;
            if (move_x > this.max_scroll_left) {
                this.current_scroll_position = this.max_scroll_left;
            } else {
                this.current_scroll_position = move_x;
            }
        }
        this.translateTable();
    },
    translateTable: function() {
        var _this = this;
        //Trigger event which can be used by other plugins
        trigger_event("scrollButtons.scroll_event",this.current_scroll_position);
        jQuery(".dataTables_scrollBody").animate({
                scrollLeft: this.current_scroll_position
            },
            this.scroll_speed,
            function() {
                _this.updateControls();
            });
    },
    handleDragScale: function() {

        var _this = this;
        _this.queryDom();
        _this.calculateMaxScroll();
        jQuery(".dataTables_scrollBody").on("scroll", function(event) {
            var scrollPosition = jQuery(_this.datatable_body).scrollLeft();
            _this.current_scroll_position = scrollPosition;
            _this.updateControls();
        });

    },
    updateControls: function() {
        if (this.current_scroll_position == 0) {
            jQuery(this.left_nav_btn).addClass(this.disable_class);
            jQuery(this.right_nav_btn).removeClass(this.disable_class);

            //Shadow
            jQuery(this.fixed_column_elements).removeClass(this.shadow_class[1]);
            jQuery(this.scrollers).addClass(this.shadow_class[0]);

        } else if (this.current_scroll_position == this.max_scroll_left ||
            this.current_scroll_position == this.max_scroll_left - 1) {
            //Because of scroll bar the scroll is not able to reach the max
            jQuery(this.right_nav_btn).addClass(this.disable_class);
            jQuery(this.left_nav_btn).removeClass(this.disable_class);

            jQuery(this.fixed_column_elements).addClass(this.shadow_class[1]);
            jQuery(this.scrollers).removeClass(this.shadow_class[0]);

        } else {
            jQuery(this.right_nav_btn).removeClass(this.disable_class);
            jQuery(this.left_nav_btn).removeClass(this.disable_class);

            //Shadow
            jQuery(this.fixed_column_elements).addClass(this.shadow_class[1]);
            jQuery(this.scrollers).addClass(this.shadow_class[0]);
        }
    },
    calculateMaxScroll: function() {
        var table = jQuery(this.datatable_body)[0];
        this.max_scroll_left = table.scrollWidth - table.clientWidth;
    },
    markup: function(oDTSettings) {

        var template = '<div class="scrollers left-shadow"> \
                            <div class="controls"> \
                                <span data-direction ="previous" data-action="data-tab-nav" class="details-prev show-metrics disable"> \
                                    <i class="ficon-arrow-left fsize-14"></i> \
                                </span> \
                                <span data-direction="forward" data-action="data-tab-nav" class="details-next show-metrics"> \
                                    <i class="ficon-arrow-right fsize-14"></i> \
                                </span> \
                            </div> \
                            <div class="empty-column"></div>';
        this.registerCallbacks(oDTSettings, template);

    },
    registerCallbacks: function(oDTSettings, template) {

        var _this = this;
        oDTSettings.aoInitComplete.push({

            "fn": function(oDTSettings) {
                jQuery(_this._wrapper).prepend(template);

                _this.queryDom();

                if (!_this.disable_draggable_scroll) {
                    _this.handleDragScale();
                } else {
                    //Disable the scrolling behaviour
                    jQuery(_this.datatable_body).css('overflow', 'hidden');
                }

            }
        });

        oDTSettings.aoDrawCallback.push({
            "fn": function(oDTSettings) {
                _this.queryDom();
                _this.adjustMarkupDimensions();
            }
        });
    },
    adjustMarkupDimensions: function() {
        setTimeout(function() {
            var tableHeight = jQuery(".dataTables_scroll").height();
            var emptyColumnHeight = tableHeight - 2; //Table Height - border
            //console.log('DataTables has redrawn the table' + tableHeight);
            jQuery(".scrollers").height(emptyColumnHeight);
        }, 0);

    },
    queryDom: function() {
        this.datatable_body = jQuery(".dataTables_scrollBody");
        this.left_nav_btn = jQuery(".details-prev");
        this.right_nav_btn = jQuery(".details-next");
        this.fixed_column_elements = jQuery(".DTFC_LeftBodyWrapper,.DTFC_LeftHeadWrapper");
        this.scrollers = jQuery(".scrollers");
    },
    cFeature: 'S'
});
})();
