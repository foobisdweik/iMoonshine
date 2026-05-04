## Objective

Configure a Shortcut that uses **iMoonshine → Toggle Recording** and correctly passes its output (the transcript) into **Copy to Clipboard** using a **magic variable**, rather than the static “Content” options you are currently seeing.

---

## Why your current approach fails

When you tap the `[Content]` field and see:

* Clipboard
* Current App
* Current Date
* Device Details
* Shortcut Input

those are **built-in system variables**, not outputs from actions.

The transcript produced by **Toggle Recording** is an **action result**, and in Apple Shortcuts it is only accessible via **magic variables** (dynamic outputs from previous actions). These do **not** appear in that static list.

---

## Full Step-by-Step Setup

### 1. Create a new shortcut

1. Open **Apple Shortcuts**
2. Tap the **“+”** button
3. Rename the shortcut (e.g., `iMoonshine Magic Shortcut`)

---

### 2. Add the iMoonshine recording action

1. Tap **Add Action**
2. Search for **iMoonshine**
3. Select **Toggle Recording**

You should now see a block labeled:

```
Toggle Recording
```

Important detail:

* This action produces output **only when you stop recording**, not when you start it.

---

### 3. Add a conditional check (If block)

This ensures the shortcut only copies text when a transcript exists.

1. Tap **Add Action**
2. Search for **If**
3. Add it

Now configure the condition:

1. Tap the condition field (it may say “Condition” or similar)
2. Choose **Select Variable**
3. From the variable list, select the output from **Toggle Recording** (it may appear as “Result” or “Toggle Recording Result”)
4. Set condition to:

   * **has any value**

You should now have something logically equivalent to:

```
If [Toggle Recording Result] has any value
```

---

### 4. Add “Copy to Clipboard” inside the If block

1. Inside the If block, tap **Add Action**
2. Search for **Copy to Clipboard**
3. Add it

You will now see:

```
Copy [Content] to Clipboard
```

---

## Critical Step: Insert the Magic Variable

This is where your issue occurs.

### What you are doing now (incorrect)

* Tapping `[Content]`
* Selecting from:

  * Clipboard
  * Current App
  * etc.

These are **not** what you want.

---

### What you need to do instead

1. Tap `[Content]`
2. Look for **“Select Variable”** or a **variable icon** (often appears above the keyboard or in a toolbar)
3. Tap that option

Now the UI will switch to showing **available variables**, including outputs from previous actions.

4. Locate and tap:

   * **Toggle Recording Result** (or similarly named output)

After selecting it, the field should change to:

```
Copy [Toggle Recording Result] to Clipboard
```

This blue token (the variable) is the **magic variable**.

---

## Final Shortcut Structure

You should now have:

```
Toggle Recording

If [Toggle Recording Result] has any value
    Copy [Toggle Recording Result] to Clipboard
End If
```

---

## Assign to Action Button (optional but intended use)

1. Open **Settings**
2. Go to **Action Button**
3. Set it to **Shortcut**
4. Choose your newly created shortcut

---

## Expected Behavior

* **First press**

  * Starts recording
  * No output → If condition fails → nothing copied

* **Second press**

  * Stops recording
  * Transcript produced
  * If condition passes
  * Transcript copied to clipboard

---

## Troubleshooting

### If “Toggle Recording Result” does not appear

* Open iMoonshine once (foreground)
* Close Shortcuts completely
* Reopen Shortcuts
* Re-add the Toggle Recording action

Reason: App Intents metadata may not have been indexed.

---

### If the Copy action still shows static options only

* Ensure you tapped **Select Variable**, not the default list
* Try long-pressing the field
* Try re-adding the Copy to Clipboard action *after* the Toggle Recording action

---

### If nothing is copied

* Verify the Copy action contains a **blue variable token**
* Confirm If condition is using the same variable

---

## Key Concept (summary)

* The list you saw = **static system inputs**
* iMoonshine output = **dynamic action result**
* Dynamic results are accessed via:

  * **Select Variable → Magic Variable**

This distinction is the root of the issue.


Below are **primary-source Apple documents** that directly support the exact behavior I described—specifically the distinction between:

* **Static variables (what you are seeing)**
* **Magic variables (what you actually need to use)**

---

## 1. Apple: How to insert a Magic Variable

From Apple’s official Shortcuts documentation:

> “Tap any text field… Tap **Select Variable**… Tap the Magic Variable (the blue token under an action).” ([Apple Support][1])

Direct link:

* [Use variables in Shortcuts (Apple Support)](https://support.apple.com/en-gb/guide/shortcuts/apdd02c2780c/ios)

### What this confirms

* You **must tap a text field first** (like `[Content]`)
* Then explicitly choose **“Select Variable”**
* Then select from **blue tokens under actions**

This exactly matches the workflow I described:

> Content field → Select Variable → pick Toggle Recording output

---

## 2. Apple: Magic Variables are action outputs

Apple explicitly states:

> “Each action is automatically available as a variable… select the result of any previous action.” ([Apple Support][2])

### What this confirms

* You do **not manually add or define** the variable
* The output from **Toggle Recording already exists**
* You only need to **select it from the magic variable view**

---

## 3. Apple: Difference between Magic vs Special variables

From the same Apple documentation:

* Magic variables = **outputs from actions**
* Special variables = **Clipboard, Date, Device, etc.** ([Apple Support][1])

### This directly explains your UI

What you saw:

* Clipboard
* Current App
* Current Date
* Device Details
* Shortcut Input

These are explicitly described by Apple as:

> “special variables… tap one of the special variables” ([Apple Support][1])

### Conclusion

You were looking at the **wrong variable category**.

---

## 4. Apple: Visual model (blue tokens)

Apple defines how magic variables appear:

> “Variables are represented by blue pill-shaped tokens.” ([Apple Support][1])

### What this means in practice

* If you do not see a **blue token** inside your field
* You are **not using a magic variable yet**

---

## 5. Apple: App actions (like iMoonshine) expose outputs

From Apple developer docs:

> “App Shortcuts use App Intents to define actions… available in the Shortcuts app.” ([Apple Developer][3])

### Implication

* iMoonshine’s **Toggle Recording** is an App Intent
* Its output (transcript) is exposed exactly like any other action output
* Therefore it **must be accessed as a magic variable**, not a static input

---

## Synthesis (tying directly to your issue)

Your exact situation:

* You tapped `[Content]`
* You saw only:

  * Clipboard
  * Current Date
  * etc.

Apple documentation explains why:

| What you saw            | Apple term            | Meaning               |
| ----------------------- | --------------------- | --------------------- |
| Clipboard, Date, etc.   | **Special variables** | Static inputs         |
| Toggle Recording output | **Magic variable**    | Dynamic action output |

And Apple explicitly separates the two workflows:

* Special variables → appear immediately in list
* Magic variables → require **Select Variable → pick blue token**

---

## Final confirmation (aligned with Apple docs)

Correct interaction path (verbatim aligned with docs):

1. Tap `[Content]`
2. Tap **Select Variable**
3. Tap blue token under **Toggle Recording**
4. Field becomes:

   ```
   Copy [Toggle Recording Result] to Clipboard
   ```

This is not an interpretation—this is **exactly the UI model Apple documents**.

---

## Bottom line

* Your observation is valid
* Your interpretation was not

You were inside the **special-variable picker**, not the **magic-variable selector**

Apple’s own documentation explicitly defines that distinction and the required interaction path.

[1]: https://support.apple.com/en-gb/guide/shortcuts/apdd02c2780c/ios "Use variables in Shortcuts on iPhone or iPad – Apple Support (UK)"
[2]: https://supportsite-uat-stage.apple.com/fr-afri/guide/shortcuts/apdd2b316022/ios "Types de variable utilisés dans Raccourcis - Assistance Apple"
[3]: https://developer.apple.com/design/human-interface-guidelines/app-shortcuts "App Shortcuts | Apple Developer Documentation"
