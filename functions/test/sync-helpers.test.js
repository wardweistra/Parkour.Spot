const {shouldRunSync} = require("../lib/sync-helpers");

describe("shouldRunSync", () => {
  it("returns true when next run has passed", () => {
    // Every minute: "* * * * *"
    const lastRun = new Date("2024-01-15T12:00:00Z");
    const now = new Date("2024-01-15T12:05:00Z");
    expect(shouldRunSync("* * * * *", lastRun, now)).toBe(true);
  });
  it("returns false when next run has not passed", () => {
    const lastRun = new Date("2024-01-15T12:00:00Z");
    const now = new Date("2024-01-15T12:00:30Z");
    // Every hour at minute 0
    expect(shouldRunSync("0 * * * *", lastRun, now)).toBe(false);
  });
  it("returns false for invalid cron expression", () => {
    const consoleSpy = jest.spyOn(console, "error").mockImplementation(() => {});
    const lastRun = new Date();
    const now = new Date();
    expect(shouldRunSync("invalid", lastRun, now)).toBe(false);
    consoleSpy.mockRestore();
  });
});
