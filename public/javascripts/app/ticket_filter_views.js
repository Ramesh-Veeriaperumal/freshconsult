(function($) {

    $.fn.filterList = function(searchBox, listClass, callback) {

        var searchElements = [],
            searchElementTexts = [];
        var listId = $('[data-picklist]');
        
        $('body').on('change.filterList', function() {
            var searchText = $(searchBox).val().toLowerCase();
            if (jQuery(searchBox).val().length > 0) {
                jQuery('.seperator').hide();
            } else {
                jQuery('.seperator').show();
            }
            searchElements.each(function(index) {
                jQuery(this).toggle(window.lookups.scenario_execution_search(searchText, searchElementTexts[index]))
            });

            var count = jQuery('[data-picklist] li:visible').size();
            if (count == 0) {
                jQuery('.no_result_view').removeClass('hide');
            } else {
                jQuery('.no_result_view').addClass('hide');
            }
        });

        $('body').on('keyup.filterList', searchBox, function(event) {
            initSearchValues();
            if (event.keyCode < 37 || event.keyCode > 41) {
                if (event.keyCode != 13) {
                    $(this).change();
                    var currActive = jQuery('[data-picklist]').children('li.active');
                    currActive.removeClass('active');
                    jQuery('[data-picklist]').find('li:visible').first().addClass('active');
                }
            }
            handleKeycode(event);
        });

        $('body').on('mouseenter.filterList', '[data-picklist] li', function(event) {
            var $list = $('[data-picklist] li');
            $('[data-picklist]')
                .on('mouseenter.filterList', 'li', function(event) {
                    if (!$(searchBox).is(':focus')) {
                        $(searchBox).focus();
                    }
                    $list.removeClass('active');
                    var src = event.srcElement || event.target;
                    var currActive = jQuery('[data-picklist]').children('li.active');
                    $(currActive).removeClass('active');
                    $(src).parent().first().addClass('active');
                });
        });



        function initSearchValues() {
            searchElements = jQuery(listClass);
            searchElementTexts = [];
            searchElements.each(function() {
                searchElementTexts.push(jQuery(this).text().toLowerCase());
            });
        }

        function handleKeycode(event) {
            switch (event.keyCode) {
                case 38:
                    switchActive(1);
                    break;
                case 40:
                    switchActive(-1);
                    break;
                case 13:
                    handleEnter(event);
                    break;
                default:
                    break;
            }
        }

        function switchActive(direction) {
            var currActive = jQuery('[data-picklist]').children('li.active');
            if (currActive.length === 0) {
                jQuery('[data-picklist]').find('li:visible').first().addClass('active');
            }
            if (direction === 1 && $(currActive).data('id') !== jQuery('[data-picklist]').children('li').first().data('id')) {
                // Move up
                $(currActive).prevAll(listClass + ":visible").first().addClass('active');
                $(currActive).removeClass('active');
                moveElement();
            }
            if (direction === -1 && $(currActive).data('id') !== jQuery('[data-picklist]').children('li').last().data('id')) {
                // Move down
                $(currActive).nextAll(listClass + ":visible").first().addClass('active');
                $(currActive).removeClass('active');
                moveElement();
            }

        }

        function moveElement() {
            var topElement = jQuery('[data-picklist] li.active') || jQuery('[data-picklist] li').first();
            if (topElement && topElement.offset()) {
                var topPosition = topElement.offset().top;
                var index = jQuery('[data-picklist] li.active').index();
                var height = jQuery('[data-picklist] li').innerHeight();
                var recentHeight = jQuery('[data-picklist] .recent').innerHeight();
                if (topPosition > 350 || topPosition < 200) {
                    jQuery('[data-picklist]').scrollTop(index * height);
                }
            }
        }

        function handleEnter() {
            var currActive = jQuery('[data-picklist]').children('li.active');
            callback(currActive);
        }
    };

}(jQuery));
