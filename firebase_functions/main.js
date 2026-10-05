'use strict';

// Transitional Firebase entry point.
// Keeps all current production callables available while V2 replaces them
// feature-by-feature. No real question content is added here.

const legacy = require('./index');
const v2 = require('./v2_functions');

module.exports = {
  ...legacy,
  ...v2,
};
