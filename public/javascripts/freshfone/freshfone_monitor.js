/**
 * Copyright (2015) FreshDesk Inc.
 * 
 * Freshfone Monitor : Monitors and reports performance metrics of calls
 **/

var PUBLISH_INTERVAL = 15000; //15000 //production
var PUBLISH_INTERVAL_AFTER_30_MINS = 60000; //60000 //production
var PUBLISH_INTERVAL_CHANGE_DURATION_IN_MINS = 30;
var PUBLISH_INTERVAL_CHANGE_DURATION = 120 //(60000/PUBLISH_INTERVAL) * PUBLISH_INTERVAL_CHANGE_DURATION_IN_MINS; // 120 //production

//acceptable limits
var MOS_DROP = 0.1;
var MOS_MAX = 4.0;
var MOS_MIN = 1.0;
var FRACTION_LOST_MIN = 5;
var FRACTION_LOST_MAX = 10;
var AVERAGE_JITTER_MIN = 400;
var AVERAGE_JITTER_MAX = 600;
var MAX_JITTER = 600 ;
var AVERAGE_GOOGJITTERBUFFERMS_MIN = 400;
var AVERAGE_GOOGJITTERBUFFERMS_MAX = 600; 
var AVERAGE_RTT_MIN = 300;  
var AVERAGE_RTT_MAX = 400;
var MAX_RTT = 500;

function FreshfoneMonitor (connectionObj) {
  this.call_sid = connectionObj.parameters.CallSid; // Call SID of the call in progress
  this.statsObject = {}; // This holds all the individual statistics gathers throughout the duration of the call
  this.currentStats = null;
  this.events = {};
  this.summaryStatsTable = { // Holds the summary of the statistics for the call. Is regularly updated
    packetsLost                 : 0,
    packetsReceived             : 0,
    codecName                   : null, // Codec being used by the browser for the audio https://webrtcglossary.com/codec/
    packetsSent                 : 0,
    average_jitter              : 0, // https://webrtcglossary.com/jitter/
    max_jitter                  : 0,
    average_googJitterBufferMs  : 0, // https://webrtcglossary.com/jitter-buffer/
    max_googJitterBufferMs      : 0,
    average_rtt                 : 0, // Round Trip Time of the packets
    max_rtt                     : 0,
    average_mos                 : 0,
    average_latency             : 0,
    browser_info                : browserInfo(),
    parameters                  : connectionObj.parameters
  };
  this.statsCount = 0;
  this._previousStat = null;
  this.previousMos = null;
  this.currentMos = null;
  var pc = connectionObj.getMediaStream();
  if (pc.version && pc.version.pc) {
    this.pc = pc;       // IMPORTANT : This gets the raw peerConnection object from twilio's media stream object
  }                     // Is the object we use to get raw stats from webRTC
  return this;
}

window.FreshfoneMonitor = FreshfoneMonitor;

FreshfoneMonitor.prototype.startLoggingWithInterval = function(interval) {
  var self = this;
  this.startTime = new Date();
  this.statsInterval = setInterval(function(){self.collectStats(self)}, interval || PUBLISH_INTERVAL);
};



FreshfoneMonitor.prototype.collectStats = function(self) { // Run this method in intervals
    getStatistics(self.pc.version.pc, function(error, stats) { // stats is the stats obtained from webrtc
      if (error) {
        self.errors = self.errors || [];
        self.errors.push(error);
      };
      if (stats) {
        self.statsCount += 1;
        // Recalculate summary
        self.summaryValue("packetsLost", stats.packetsLost); // These are cumulative statstics. Can be just copied
        self.summaryValue("packetsReceived", stats.packetsReceived);
        self.summaryValue("packetsSent", stats.packetsSent);
        self.summaryValue("bytesSent", stats.bytesSent);
        self.averageSummaryValue("jitter", stats.jitter); // Non cumulative statistics. Average should be recalculated
        self.averageSummaryValue("googJitterBufferMs", stats.googJitterBufferMs);
        self.averageSummaryValue("rtt", stats.rtt);
        stats.time = new Date().toUTCString();
        self.currentStats = self.getMoreStats(stats, self.summaryStatsTable);

        if(self.currentStats.mos && isQualityLow(self.currentStats, self.summaryStatsTable)){
          self.events[self.statsCount] = self.extractStats(stats);
        }
        if(self.currentStats.mos && isQualityVeryLow(self.currentStats, self.summaryStatsTable)){
          clearInterval(self.statsInterval);
        }
        self.statsObject.events = self.events;
        self.resetInterval();
      }
    });
  }

FreshfoneMonitor.prototype.extractStats = function(stats){
  var extractedStats = {};
  extractedStats.effective_latency = stats.effective_latency;
  extractedStats.fraction_lost = stats.fraction_lost;
  extractedStats.googJitterBufferMs = stats.googJitterBufferMs;
  extractedStats.jitter = stats.jitter;
  extractedStats.mos = stats.mos;
  extractedStats.mos_drop = stats.mos_drop;
  extractedStats.packetsLost = stats.packetsLost;
  extractedStats.packetsSent = stats.packetsSent;
  extractedStats.packetsReceived = stats.packetsReceived;
  extractedStats.rtt = stats.rtt;
  extractedStats.time = stats.time;
  extractedStats.timestamp = stats.timestamp;
  return extractedStats;
}

FreshfoneMonitor.prototype.resetInterval = function(){
  var self = this;
  if(this.statsCount==PUBLISH_INTERVAL_CHANGE_DURATION){ // 120 production
    clearInterval(this.statsInterval);
    this.statsInterval = setInterval(function(){self.collectStats(self)}, PUBLISH_INTERVAL_AFTER_30_MINS);
  }
}

FreshfoneMonitor.prototype.getMoreStats = function(stats){
  if(this.currentMos) 
    this.previousMos = this.currentMos;
  stats.mos = this.calculateMosScore(stats);
  this.currentMos = stats.mos;
  if(this.previousMos && stats.mos)  stats.mos_drop = this.previousMos - stats.mos;
  if(stats.mos)  this.summaryStatsTable.average_mos = this.average("mos",stats.mos);
  if(stats.effective_latency) this.summaryStatsTable.average_latency = this.average("latency",stats.effective_latency);
  return stats;
}


FreshfoneMonitor.prototype.average = function(key,value){
  return (this.summaryStatsTable["average_"+key] * (this.statsCount-2) + parseFloat(value) ) / (this.statsCount-1);
}

FreshfoneMonitor.prototype.summaryValue = function(key, value) { // For cumulative stats
  if (value) this.summaryStatsTable[key] = value
}

FreshfoneMonitor.prototype.averageSummaryValue = function(key, value) {
  if (value) { // Average calculation => [(AVGn * n) + K<n+1>]/n+1
    this.summaryStatsTable["average_" + key] = (this.summaryStatsTable["average_" + key] * (this.statsCount - 1) + parseInt(value)) / this.statsCount;
    if (parseInt(value) > this.summaryStatsTable["max_" + key]) this.summaryStatsTable["max_" + key] = parseInt(value);
  }
}

FreshfoneMonitor.prototype.stopLogging = function() {
  clearInterval(this.statsInterval);
  this.endTime = new Date(); // Calculate and reformat call duration
  this.summaryStatsTable.call_duration = (new Date(this.endTime - this.startTime)).toUTCString().match(/(\d\d:\d\d:\d\d)/)[0];
  this.summaryStatsTable.call_at = this.startTime.toUTCString();
  this.statsObject["Summary"] = this.summaryStatsTable;
  freshfonecalls.saveCallQualityMetrics(this.statsObject);
};


function isQualityLow(stats, summaryStatsTable){
  return (isMosLow(stats) 
    || isMosDroppingRapidly(stats) 
    || isPacketsLossHigh(stats)
    || isJitterHigh(summaryStatsTable)
    || isJitterBufferHigh(summaryStatsTable)
    || isRttHigh(summaryStatsTable) 
    );
}

function isMosLow(stats){
  return stats.mos < MOS_MAX;
}

function isMosDroppingRapidly(stats){
  return stats.mos_drop >= MOS_DROP;
}

function isPacketsLossHigh(stats){
  return stats.FRACTION_LOST > FRACTION_LOST_MIN;
}

function isJitterHigh(summaryStatsTable){
  return summaryStatsTable.average_jitter > AVERAGE_JITTER_MIN;
}

function isJitterBufferHigh(summaryStatsTable){
  return summaryStatsTable.average_googJitterBufferMs > AVERAGE_GOOGJITTERBUFFERMS_MIN;
}

function isRttHigh(summaryStatsTable){
  return summaryStatsTable.average_rtt > AVERAGE_RTT_MIN;
}

function isQualityVeryLow(stats, summaryStatsTable){
  return (isMosVeryLow(stats) 
    || isTooMuchPacketsLost(stats) 
    || isTooMuchJitter(summaryStatsTable) 
    || isJitterBufferTooHigh(summaryStatsTable) 
    || isRttTooHigh(summaryStatsTable) 
    );
}

function isMosVeryLow(stats){
  return stats.mos < MOS_MIN;
}

function isTooMuchPacketsLost(stats){
  return stats.fraction_lost > FRACTION_LOST_MAX;
}

function isTooMuchJitter(summaryStatsTable){
  return summaryStatsTable.average_jitter > AVERAGE_JITTER_MAX || summaryStatsTable.max_jitter > MAX_JITTER;
}

function isJitterBufferTooHigh(summaryStatsTable){
  return summaryStatsTable.average_googJitterBufferMs > AVERAGE_GOOGJITTERBUFFERMS_MAX;
}

function isRttTooHigh(summaryStatsTable){
  return summaryStatsTable.average_rtt > AVERAGE_RTT_MAX || summaryStatsTable.max_rtt > MAX_RTT;
}
/**
 * Collect any WebRTC statistics for the given {@link PeerConnection} and pass
 * them to an error-first callback.
 * @param {PeerConnection} peerConnection - The {@link PeerConnection}
 * @param {function} callback - The callback
 */
function getStatistics(peerConnection, callback) {
  var error = new Error('WebRTC statistics are unsupported');
  if (typeof navigator === 'undefined' || typeof peerConnection.getStats !== 'function') {
    callback(error);
  } else if (navigator.webkitGetUserMedia) {
    peerConnection.getStats(chainCallback(withStats, callback), callback);
  } else if (navigator.mozGetUserMedia) {
    peerConnection.getStats(null, chainCallback(mozWithStats, callback), callback);
  } else {
    callback(error);
  }
}

/**
 * Handle any WebRTC statistics for Google Chrome and pass them to an error-
 * first callback.
 * @param {RTCStatsResponse} response - WebRTC statistics for Google Chrome
 * @param {function} callback - The callback
 */
function withStats(response, callback) {
  var knownStats = [];
  var unknownStats = [];
  var results = response.result();
  results.forEach(function(report) {
    var processedReport = null;
    switch (report.type) {
      case 'googCandidatePair':
        processedReport = processCandidatePair(report);
        break;
      case 'ssrc':
        processedReport = processSSRC(report);
        break;
      // Unknown
      default:
        unknownStats.push(report);
    }
    if (processedReport) {
      knownStats.push(processedReport);
    }
  });
  if (knownStats.length === 0 || (knownStats = filterKnownStats(knownStats)).length === 0) {
    return callback(null, {});
  }
  var mergedStats = knownStats.reduceRight(function(mergedStat, knownStat) {
    for (var name in knownStat) {
      mergedStat[name] = knownStat[name];
    }
    return mergedStat;
  }, {});
  callback(null, mergedStats);
}

function processCandidatePair(report) {
  var knownStats = {};
  var unknownStats = {};
  var names = report.names();
  var timestamp = report.timestamp ? Math.floor(report.timestamp/1000) : null;
  for (var i = 0; i < names.length; i++) {
    var name = names[i];
    var value = report.stat(name);
    switch (name) {
      // If the connection represented by this report is inactive, bail out.
      case 'googActiveConnection':
        if (value !== 'true') {
          return null;
        }
        break;
      // Rename "goog"-prefixed stats.
      case 'googLocalAddress':
        knownStats['localAddress'] = value;
        break;
      case 'googRemoteAddress':
        knownStats['remoteAddress'] = value;
        break;
      case 'googRtt':
        knownStats['rtt'] = Number(value);
        break;
      // Ignore empty stat names (annoying, I know).
      case '':
        break;
      // Unknown
      default:
        unknownStats[name] = value;
    }
  }
  knownStats.timestamp = timestamp;
  return packageStats(knownStats, unknownStats);
}

function processSSRC(report) {
  var knownStats = {};
  var unknownStats = {};
  var names = report.names();
  var timestamp = report.timestamp ? Math.floor(report.timestamp/1000) : null;
  names.forEach(function(name) {
    var value = report.stat(name);
    switch (name) {
      // Rename "goog"-prefixed stats.
      case 'googCodecName':
        // Filter out the empty case.
        var codecName = value;
        if (codecName !== '') {
          knownStats['codecName'] = value;
        }
        break;
      case 'googJitterBufferMs':
        knownStats['googJitterBufferMs'] = Number(value);
        break;
      case 'googJitterReceived':
        // Filter out the -1 case.
        var jitterReceived = Number(value);
        if (jitterReceived !== -1) {
          knownStats['jitter'] = jitterReceived;
        }
        break;
      // Pass these stats through unmodified.
      case 'bytesReceived':
      case 'bytesSent':
      case 'packetsReceived':
      case 'packetsSent':
      case 'timestamp':
      case 'audioInputLevel':
      case 'audioOutputLevel':
        knownStats[name] = Number(value);
        break;
      case 'packetsLost':
        // Filter out the -1 case.
        var packetsLost = Number(value);
        if (packetsLost !== -1) {
          knownStats[name] = packetsLost;
        }
        break;
      // Unknown
      default:
        unknownStats[name] = value;
    }
  });
  knownStats.timestamp = timestamp;
  return packageStats(knownStats, unknownStats);
}

/**
 * Handle any WebRTC statistics for Mozilla Firefox and pass them to an error-
 * first callback.
 * @param {RTCStatsReport} reports - WebRTC statistics for Mozilla Firefox
 * @param {function} callback - The callback
 */
function mozWithStats(reports, callback) {
  var knownStats = [];
  var unknownStats = []
  reports.forEach(function(report) {
    var processedReport = null;
    switch (report.type) {
      case 'inboundrtp':
        processedReport = processInbound(report);
        break;
      case 'outboundrtp':
        if (report.isRemote === false) {
          processedReport = processOutbound(report);
        }
        break;
      // Unknown
      default:
        unknownStats.push(report);
    }
    if (processedReport) {
      knownStats.push(processedReport);
    }
  });
  if (knownStats.length === 0 || (knownStats = filterKnownStats(knownStats)).length === 0) {
    return callback(null, {});
  }
  var mergedStats = knownStats.reduceRight(function(mergedStat, knownStat) {
    for (var name in knownStat) {
      mergedStat[name] = knownStat[name];
    }
    return mergedStat;
  }, {});
  callback(null, mergedStats);
}

function processOutbound(report) {
  var knownStats = {};
  var unknownStats = {};
  for (var name in report) {
    var value = report[name];
    switch (name) {
      // Convert to UNIX timestamp.
      case 'timestamp':
          knownStats[name] = Math.floor(value/1000);
      // Pass these stats through unmodified.
      case 'bytesSent':
      case 'packetsSent':
        knownStats[name] = value;
        break;
      // Unknown
      default:
        unknownStats[name] = value;
    }
  }
  return packageStats(knownStats, unknownStats);
}

function processInbound(report) {
  var knownStats = {};
  var unknownStats = {};
  for (var name in report) {
    var value = report[name];
    switch (name) {
      // Rename "moz"-prefixed stats.
      case 'mozRtt':
        knownStats['rtt'] = value;
        break;
      // Convert to UNIX timestamp.
      case 'timestamp':
        knownStats[name] = Math.floor(value/1000);
        break;
      // Convert to milliseconds.
      case 'jitter':
        knownStats[name] = value * 1000;
        break;
      // Pass these stats through unmodified.
      case 'bytesReceived':
      case 'packetsLost':
      case 'packetsReceived':
        knownStats[name] = value;
        break;
      // Unknown
      default:
        unknownStats[name] = value;
    }
  }
  return packageStats(knownStats, unknownStats);
}

/**
 * Given two objects containing known and unknown WebRTC statistics, include
 * each in an object keyed by "known" or "unkown" if they are non-empty. If
 * both are empty, return null.
 * @param {?object} knownStats - Known WebRTC statistics
 * @param {?object} unknownStats - Unkown WebRTC statistics
 * @returns ?object
 */
function packageStats(knownStats, unknownStats) {
  var stats = null;
  if (!empty(knownStats)) {
    stats = stats || {};
    stats.known = knownStats;
  }
  if (!empty(unknownStats)) {
    stats = stats || {};
    stats.unknown = unknownStats;
  }
  return stats;
}

/**
 * Given a list of objects containing known and/or unknown WebRTC statistics,
 * return only the known statistics.
 * @param {Array} stats - A list of objects containing known and/or unknown
 *                        WebRTC statistics
 * @returns Array
 */
function filterKnownStats(stats) {
  var knownStats = [];
  for (var i = 0; i < stats.length; i++) {
    var stat = stats[i];
    if (stat.known) {
      knownStats.push(stat.known);
    }
  }
  return knownStats;
}

/**
 * Check if an object is "empty" in the sense that it contains no keys.
 * @param {?object} obj - The object to check
 * @returns boolean
 */
function empty(obj) {
  if (!obj) {
    return true;
  }
  for (var key in obj) {
    return false;
  }
  return true;
}

/**
 * Given a function that takes a callback as its final argument, fix that final
 * argument to the provided callback.
 * @param {function} function - The function
 * @param {function} callback - The callback
 * @returns function
 */
function chainCallback(func, callback) {
  return function() {
    var args = Array.prototype.slice.call(arguments);
    args.push(callback);
    return func.apply(null, args);
  };
}


FreshfoneMonitor.prototype.calculateMosScore = function calculateMosScore(currentStat) {
  if(!this._previousStat || !currentStat) {
    this._previousStat = currentStat;
    return null;
    }
    var mos;
    try {
      mos = setMosParams(currentStat, this._previousStat)
      if(mos) {
        mos = parseFloat(Math.round(mos * 100) / 100).toFixed(2)
      }
    } catch(exception) {
      this.log('Exception calculating mos ' + exception)
    } finally {
      this._previousStat = currentStat;
      return mos;
  }
}

/**
 *
 * Calculate the mos score based on the previous and current stats
 * It will go through rtt, jitter, received_packets_lost, received_packets
 * to calculate mos score.
 * @param {object} currentStat - Current stat
 * @return {object} previousStat - Previous stat
 */
function setMosParams(currentStat, previousStat) {
  var mos = null;
  var rtt = currentStat.rtt ? currentStat.rtt : previousStat.rtt;
  rtt = rtt ? rtt : 0;

  // Fetch jitter for current stats.
  var jitter = currentStat.jitter ? currentStat.jitter : 0;

  // Total Packets received between the interval.
  var totalPacket = currentStat.packetsReceived - previousStat.packetsReceived;

  // Packet Lost between the interval, 0 if undefined.
  var packetLost = currentStat.packetsLost ? currentStat.packetsLost : 0;

  // Actual total packets intended to sent by remote endpoint = received + dropped.
  totalPacket = totalPacket + packetLost;

  // Calculate Mos.
  mos = calculateMosParams(rtt, jitter, totalPacket, packetLost, currentStat);
  return mos;
}

function calculateMosParams(rtt, jitter, totalPacket, packetLost, currentStat) {
  var effectiveLatency = calculateEffectiveLatency(rtt, jitter);
  var fractionLost = calculateFractionLost(totalPacket, packetLost);
  currentStat.effective_latency = effectiveLatency;
  currentStat.fraction_lost = fractionLost;
  var rFactor = calculateRFactor(effectiveLatency, fractionLost);
  return calculateMos(rFactor);
}

function calculateMos(rFactor) {
  var mos =  1 + (0.035 * rFactor) + (0.000007 * rFactor) * ( rFactor - 60) * (100 - rFactor);
  return mos;
}

function calculateRFactor(effectiveLatency, fractionLost) {
  var rFactor = 0;

  switch(true) {
    case effectiveLatency < 160 :
      rFactor = rfactorConstants.r0 - (effectiveLatency / 40);
      break;
    case effectiveLatency < 1000 :
      rFactor = rfactorConstants.r0 -  ( (effectiveLatency - 120) / 10 )
      break;
    case effectiveLatency >= 1000 :
      rFactor = rfactorConstants.r0 -  ( (effectiveLatency) / 100 )
      break;
  }

  var multiplier = .01;
  switch(true) {
    case fractionLost == -1:
      multiplier = 0;
      rFactor = 0;
      break;
    case fractionLost <= (rFactor/2.5):
      multiplier = 2.5
      break;
    case fractionLost > (rFactor/2.5) && fractionLost < 100 :
      multiplier = .25
      break;
  }

  rFactor = rFactor - (fractionLost * multiplier);
  return rFactor;
}

function calculateFractionLost(totalPacket, packetLost) {
  var fractionLost = ( packetLost / totalPacket ) * 100;
  if(isNaN(fractionLost)) return -1;
  return fractionLost;
}

function calculateEffectiveLatency(rtt, jitter) {
  var effectiveLatency = rtt + (jitter * 2 ) + 10;
  return effectiveLatency;
}

var rfactorConstants = {
  r0: 94.768,
  is: 1.42611
}

function browserInfo(){
  var nVer = navigator.appVersion;
  var nAgt = navigator.userAgent;
  var browserName  = navigator.appName;
  var fullVersion  = ''+parseFloat(navigator.appVersion); 
  var majorVersion = parseInt(navigator.appVersion,10);
  var nameOffset,verOffset,ix;

  // In Opera 15+, the true version is after "OPR/" 
  if ((verOffset=nAgt.indexOf("OPR/"))!=-1) {
    browserName = "Opera";
    fullVersion = nAgt.substring(verOffset+4);
  }
  // In older Opera, the true version is after "Opera" or after "Version"
  else if ((verOffset=nAgt.indexOf("Opera"))!=-1) {
    browserName = "Opera";
    fullVersion = nAgt.substring(verOffset+6);
    if ((verOffset=nAgt.indexOf("Version"))!=-1) 
      fullVersion = nAgt.substring(verOffset+8);
  }
  // In MSIE, the true version is after "MSIE" in userAgent
  else if ((verOffset=nAgt.indexOf("MSIE"))!=-1) {
    browserName = "Microsoft Internet Explorer";
    fullVersion = nAgt.substring(verOffset+5);
  }
  // In Chrome, the true version is after "Chrome" 
  else if ((verOffset=nAgt.indexOf("Chrome"))!=-1) {
    browserName = "Chrome";
    fullVersion = nAgt.substring(verOffset+7);
  }
  // In Safari, the true version is after "Safari" or after "Version" 
  else if ((verOffset=nAgt.indexOf("Safari"))!=-1) {
    browserName = "Safari";
    fullVersion = nAgt.substring(verOffset+7);
    if ((verOffset=nAgt.indexOf("Version"))!=-1) 
      fullVersion = nAgt.substring(verOffset+8);
  }
  // In Firefox, the true version is after "Firefox" 
  else if ((verOffset=nAgt.indexOf("Firefox"))!=-1) {
    browserName = "Firefox";
    fullVersion = nAgt.substring(verOffset+8);
  }
  // In most other browsers, "name/version" is at the end of userAgent 
  else if ( (nameOffset=nAgt.lastIndexOf(' ')+1) < 
            (verOffset=nAgt.lastIndexOf('/')) ) {
    browserName = nAgt.substring(nameOffset,verOffset);
    fullVersion = nAgt.substring(verOffset+1);
    if (browserName.toLowerCase()==browserName.toUpperCase()) {
      browserName = navigator.appName;
    }
  }
  // trim the fullVersion string at semicolon/space if present
  if ((ix=fullVersion.indexOf(";"))!=-1)
     fullVersion=fullVersion.substring(0,ix);
  if ((ix=fullVersion.indexOf(" "))!=-1)
    fullVersion=fullVersion.substring(0,ix);

  majorVersion = parseInt(''+fullVersion,10);
  if (isNaN(majorVersion)) {
    fullVersion  = ''+parseFloat(navigator.appVersion); 
    majorVersion = parseInt(navigator.appVersion,10);
  }

  return {
    "browser_name": browserName,
    "full_version": fullVersion
  };
}
