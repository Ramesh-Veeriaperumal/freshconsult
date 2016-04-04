/**
 * - Highcharts plugin - Work around for tooltip issue, which doesnot 
 *   disappear in column chart when moving vertically over it. 
 * - This is suggested in highcharts forum officially.
 */

(function (H) {
    H.Chart.prototype.callbacks.push(function (chart) {
        if(chart.options.chart.type === 'column') {
            H.addEvent(chart.container, 'mouseover', function (e) {
                var hoverSeries = chart.hoverSeries,
                    pointer = chart.pointer;
                if (!pointer.inClass(e.toElement || e.relatedTarget, 'highcharts-tracker')) {
                    pointer.reset();
                }
            });
        }
    });
}(Highcharts));