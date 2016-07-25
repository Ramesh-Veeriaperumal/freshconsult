
/* Extend the Highcharts.Tooltip class using the Highcharts.wrap
*/
(function (H) {
    H.wrap(H.Tooltip.prototype, 'hide', function () {
    	jQuery(document).trigger('tooltip_hidden');
    });
}(Highcharts));