/**
 * Sync scheduling helpers for ParkourSpot Cloud Functions
 */

const cronParser = require("cron-parser");

/**
 * Determines if a sync should run based on cron schedule
 * @param {string} cronExpression - Cron expression (e.g., "0 2 *\/3 * *")
 * @param {Date} lastRun - Last time this sync ran
 * @param {Date} now - Current time
 * @return {boolean} Whether sync should run
 */
function shouldRunSync(cronExpression, lastRun, now) {
  try {
    const interval = cronParser.parseExpression(cronExpression, {tz: "UTC"});

    // Get the next scheduled time after lastRun
    interval.reset(lastRun);
    const nextScheduled = interval.next().toDate();

    // If next scheduled time has passed, we should run
    return nextScheduled <= now;
  } catch (error) {
    console.error(`Invalid cron expression: ${cronExpression}`, error);
    return false;
  }
}

module.exports = {
  shouldRunSync,
};
