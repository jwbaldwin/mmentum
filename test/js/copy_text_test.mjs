import assert from "node:assert/strict"
import {test} from "node:test"
import CopyText from "../../assets/js/hooks/copy_text.js"

function mountCopy(writeText) {
  const classes = new Set(["sr-only"])
  const status = {
    textContent: "",
    classList: {
      add: (...names) => names.forEach(name => classes.add(name)),
      remove: (...names) => names.forEach(name => classes.delete(name))
    }
  }
  const content = {textContent: "first\nsecond"}
  const label = {textContent: "Copy"}
  const button = {disabled: false}
  const elements = {
    "[data-copy-content]": content,
    "[data-copy-label]": label,
    "[data-copy-status]": status,
    "[data-copy-button]": button
  }
  const listeners = new Map()
  const timers = new Map()
  let timerId = 0

  Object.defineProperty(globalThis, "navigator", {configurable: true, value: {clipboard: {writeText}}})
  globalThis.window = {
    setTimeout: callback => {timers.set(++timerId, callback); return timerId},
    clearTimeout: id => timers.delete(id)
  }

  const hook = {
    ...CopyText,
    el: {
      querySelector: selector => elements[selector],
      contains: element => element === button,
      addEventListener: (name, callback) => listeners.set(name, callback),
      removeEventListener: name => listeners.delete(name)
    }
  }
  hook.mounted()

  return {
    hook, content, label, status, button, classes, timers, listeners,
    click: () => listeners.get("click")({target: {closest: () => button}})
  }
}

test("copies the exact text and resets its success feedback", async () => {
  let copied
  const copy = mountCopy(async text => {copied = text})
  await copy.click()
  assert.equal(copied, "first\nsecond")
  assert.equal(copy.label.textContent, "Copied")
  assert.equal(copy.button.disabled, false)
  assert.equal(copy.status.textContent, "Copied to clipboard")
  for (const callback of [...copy.timers.values()]) callback()
  assert.equal(copy.label.textContent, "Copy")
  assert.equal(copy.status.textContent, "")
  copy.hook.destroyed()
})

test("clipboard rejection leaves a visible manual-copy instruction", async () => {
  const copy = mountCopy(async () => {throw new Error("Clipboard denied")})
  await copy.click()
  assert.equal(copy.label.textContent, "Try again")
  assert.equal(copy.button.disabled, false)
  assert.equal(copy.classes.has("sr-only"), false)
  assert.match(copy.status.textContent, /Select the text/)
  copy.hook.destroyed()
})

test("retrying a failed copy clears the error and shows success only after copying", async () => {
  let attempts = 0
  const copy = mountCopy(async () => {
    if (++attempts === 1) throw new Error("Clipboard denied")
  })
  await copy.click()
  assert.equal(copy.classes.has("sr-only"), false)
  await copy.click()
  assert.equal(copy.classes.has("sr-only"), true)
  assert.equal(copy.label.textContent, "Copied")
  assert.equal(copy.status.textContent, "Copied to clipboard")
  copy.hook.destroyed()
})

test("changing clients ignores stale clipboard completion and resets the button", async () => {
  let finish
  const copy = mountCopy(() => new Promise(resolve => {finish = resolve}))
  const copying = copy.click()
  assert.equal(copy.button.disabled, true)
  copy.content.textContent = "new client configuration"
  copy.hook.updated()
  finish()
  await copying
  assert.equal(copy.label.textContent, "Copy")
  assert.equal(copy.status.textContent, "")
  assert.equal(copy.button.disabled, false)
  copy.hook.destroyed()
})

test("destroying the hook removes its listener and ignores pending completion", async () => {
  let finish
  const copy = mountCopy(() => new Promise(resolve => {finish = resolve}))
  const copying = copy.click()
  copy.hook.destroyed()
  finish()
  await copying
  assert.equal(copy.listeners.size, 0)
  assert.equal(copy.timers.size, 0)
  assert.equal(copy.status.textContent, "")
})
