# Virtual Keyboard

On-screen keyboard for typing in chat and other text fields without a physical keyboard.

## Activation

When **Enable Virtual Keyboard** is on, the keyboard appears when:
- You open the chat input
- You press **A** on a text field with the controller cursor

## Login and character selection

The addon is not loaded on the account login screen, so the DLL provides a native keyboard there. Press **X** (Square on DualSense) to open it; **X** or **Back** closes it. The left stick and D-pad move the selection, **A** types, **B** is Backspace, **LB** is Space, **RB** is Tab, **LT** toggles uppercase and symbols, and **Y** / **Start** sends Enter. The overlay does not take focus from the game, and typed characters go to the focused login field. After a logout, the addon re-enables the same keyboard on the character-selection screen.

## Layout

The keyboard follows the selected addon language by default. In **Chat Settings**,
choose **Keyboard Layout** to keep that automatic behavior or select English
(QWERTY), German (QWERTZ), French (AZERTY), or Spanish (QWERTY) independently.
French includes accented letters; German includes **ä**, **ö**, **ü**, and **ß**;
Spanish includes **ñ** and accented vowels.
- Number keys (0-9)
- Common punctuation
- Space bar
- Enter/Send
- Backspace
- Shift for capitals
- Emotes mode for common emote commands

Shift updates both the key labels and the character entered. Backspace removes
one complete character, including accented letters.
Select **EMOTES** or press the right trigger (RT on Xbox, R2 on PlayStation) to
change the letter keys into 48 emote commands. Select **EMOTES** or press the
right trigger again to return to typing. The full
slash command appears in the key tooltip while emote mode is active.

## Navigation

| Action | Control |
|--------|---------|
| Move between keys | D-Pad |
| Press selected key | A Button (Cross on PlayStation) |
| Delete the previous character | Select the **DEL** key on the virtual keyboard |
| Send chat message | X in focus mode, or select **ENTER** on the virtual keyboard |
| Apply a settings edit | X in focus mode, or select **ENTER** on the virtual keyboard |
| Close keyboard | B Button (Circle on PlayStation) or Escape |

When pointer-click mode is active, **A/X** click at the physical pointer, even
while the keyboard is open. To send or apply with a controller button, switch
**RS/R3** back to focus mode; selecting **ENTER** on the virtual keyboard also
sends or applies the text.

Keyboard keys can also be assigned in the game's Key Bindings screen. The
physical **Enter** key sends text through the focused chat edit box. **Start**
opens the radial menu when the keyboard is closed; it does not send chat text.
Button names here use Xbox labels; PlayStation **A/B/X/Y** prompts are
Cross/Circle/Square/Triangle.
Controller focus starts near the center of the home row each time the keyboard
opens, so common letters are close without a trip from the number row.
In settings text fields, **ENTER** applies the value and returns focus to the settings page. **B** or **Escape** cancels the current edit and restores its starting value.

## Chat Integration

When the keyboard is open:
1. Recent chat and the input move above the keyboard, leaving more of the game visible
2. Type your message using the on-screen keyboard
3. Press **X** or select **ENTER** to send the message
4. Press Escape or select the close control to close chat input without sending

You can switch between controller typing and a physical keyboard without
losing the current draft. Virtual keys insert at the edit cursor when the game
client exposes cursor-aware edit-box input; otherwise typing keeps the existing
append behavior.
Guild, Party, Whisper, and channel shortcuts appear for chat input only. Selecting
another shortcut replaces the current channel prefix and keeps the message text.
When the keyboard is used in a settings text field, the action keys expand to
fill the bottom row.

## Configuration

| Setting | Description | Location |
|---------|-------------|----------|
| Enable Virtual Keyboard | Allow the on-screen keyboard for chat and controller-focused text fields | Chat Settings |
| Keyboard Layout | Follow the addon language or choose English, German, French, or Spanish | Chat Settings |

## Tips

- The keyboard supports both uppercase and lowercase
- Use Shift key for capital letters
- Great for quick chat messages with a controller
- For long typing sessions, consider using a physical keyboard

## Suggestions and saved phrases

The keyboard can show explicit word suggestions while using virtual typing. Select a suggestion to replace the current virtual typing word; there is no automatic correction. Slash-command input is left alone. Remembered words are optional and per character. Saved phrases are also per character and can be added or removed from the phrase controls; use them for repeated chat text. Suggestions are conservative and may not appear when the client cannot safely identify the current word or cursor state. The physical keyboard draft remains synchronized with the virtual keyboard.

The controller's direct space and backspace actions remain available while the keyboard is open. Use the dedicated suggestion controls to insert a displayed word or phrase.
