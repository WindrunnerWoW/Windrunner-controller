# Useful Macros

## Check Current Bonus Bar

### Simple Version
Shows the current bonus bar number:
```
/script local b=GetBonusBarOffset()or 0;DEFAULT_CHAT_FRAME:AddMessage("Bonus Bar: "..b)
```

### Detailed Version (with Action Slots)
Shows bonus bar number and action slot range:
```
/script local b=GetBonusBarOffset()or 0;local o=60+(b*12);DEFAULT_CHAT_FRAME:AddMessage("Bonus Bar: "..b.." | Slots: "..(o+1).."-"..(o+10))
```

### Druid Form Version
Shows bonus bar, slots, and current form name:
```
/script local b=GetBonusBarOffset()or 0;local o=60+(b*12);DEFAULT_CHAT_FRAME:AddMessage("Bonus Bar: "..b.." | Slots: "..(o+1).."-"..(o+10));local _,c=UnitClass("player");if c=="DRUID"then local n=GetNumShapeshiftForms()or 0;for i=1,n do local _,name,active=GetShapeshiftFormInfo(i);if active==1 then DEFAULT_CHAT_FRAME:AddMessage("Form: "..(name or"Caster"));break end end end
```

This shows the game's bonus-bar value. Windrunner-Controller also maps Travel
Form to its custom bar 4 (slots 109-118), so the macro's range can differ from
the controller bar while you are in Travel Form.

## How to Use

1. Press **Escape** → **Macros**
2. Click **New** to create a macro
3. Give it a name (e.g., "Check Bonus Bar")
4. Paste one of the scripts above into the macro text box
5. Click **Save**
6. Drag the macro to your action bar or assign a keybind

## Output Examples

- `Bonus Bar: 0 | Slots: 1-10` = Caster or Aquatic form / No stance
- `Bonus Bar: 1 | Slots: 73-82` = Cat Form
- `Bonus Bar: 3 | Slots: 97-106` = Bear Form
- `Bonus Bar: 5 | Slots: 121-130` = Moonkin Form

Aquatic Form uses the regular action bar (slots 1-10), so it has no separate
bonus-bar range or row in the placement frame.
