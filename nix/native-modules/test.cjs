const assert = require("node:assert");

async function main() {
  const Database = require("better-sqlite3");
  const database = new Database(":memory:");
  assert.equal(database.prepare("select 42 as value").get().value, 42);
  database.close();

  const pty = require("node-pty");
  const terminal = pty.spawn(process.env.TEST_SHELL, ["-c", "printf pty-ok"], {
    cols: 80,
    rows: 24,
    env: process.env,
    name: "xterm",
  });
  let output = "";
  terminal.onData((data) => {
    output += data;
  });
  await new Promise((resolve, reject) => {
    terminal.onExit(({ exitCode }) => {
      if (exitCode === 0) resolve();
      else reject(new Error(`PTY exited with ${exitCode}`));
    });
  });
  assert.match(output, /pty-ok/);

  const HID = require("node-hid");
  assert.ok(Array.isArray(HID.devices()));

  const bindings = require("@serialport/bindings-cpp");
  assert.ok(Array.isArray(await bindings.autoDetect().list()));

  console.log("native modules: sqlite, pty, HID, serialport OK");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
