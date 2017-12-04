// This script is run in a [dedictaed web worker thread](https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Using_web_workers)
// The motivation of this script is to use [match-sorter](https://github.com/kentcdodds/match-sorter) library
// The library performs simple, expected, and deterministic best-match sorting of an array in JavaScript
// We are forced to spawn a worker thread because the original browser environment has overriden native objects like Array which renders using some third-party library impossible.
// A new worker thread helps to reset the method definitions on native objects

importScripts('match-sorter.js');

onmessage = function (e) {
  var allItems = e.data.items;
  var keyword = e.data.keyword;

  var results = matchSorter(allItems, keyword)
  postMessage(results);
};
