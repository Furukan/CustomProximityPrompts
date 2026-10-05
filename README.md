# CustomProximityPrompts

A small client module that draws custom UI for `ProximityPrompt`s. Each prompt picks a theme: a `BillboardGui` you
design in Studio for the look, and optional hooks where you write its animations and its hold fill. The module only
does the wiring every custom prompt needs; how a theme moves is up to you.

```toml
[dependencies]
CustomProximityPrompts = "furukan/customproximityprompts@0.1.0"
```

## Usage

Register your themes and start the module once on the client:

```luau
local CustomProximityPrompts = require(ReplicatedStorage.Packages.CustomProximityPrompts)

CustomProximityPrompts:RegisterTheme("Default", {
	Template = ReplicatedStorage.Assets.ProximityPrompts.Default,
	OnShown = function(context) end,
	OnHidden = function(context) end,
	OnProgress = function(context, alpha) end,
})

CustomProximityPrompts:Start()
```

Only prompts with `Style = Custom` are drawn; Roblox keeps drawing `Default` ones. A prompt chooses its theme with a
`Theme` string attribute and falls back to `Default` when it has none or names a theme that is not registered.

`Create` makes a custom prompt from a property table; `Theme` becomes the attribute and `Parent` is set last:

```luau
local prompt = CustomProximityPrompts:Create({
	ActionText = "Sell",
	HoldDuration = 0.25,
	KeyboardKeyCode = Enum.KeyCode.X,
	Theme = "Red",
	Parent = attachment,
})
```

## Templates

A theme's `Template` is a `BillboardGui`. Each time its prompt is shown it is cloned, adorned to the prompt's parent and
put in a `CustomProximityPrompts` ScreenGui under `PlayerGui`. These descendants are filled in when present, found by
name anywhere in the template:

| Name | Class | Filled with |
|------|-------|-------------|
| `ActionText` | TextLabel | `prompt.ActionText` |
| `ObjectText` | TextLabel | `prompt.ObjectText` |
| `KeyText` | TextLabel | the key to press; visible only when the key is shown as text |
| `KeyImage` | ImageLabel | the gamepad button or the touch icon; visible only when the key is shown as an image |
| `Button` | GuiButton | pressing it holds the prompt, on touch or when `ClickablePrompt` is on |

They are refreshed whenever a property of the prompt changes. `UIOffset` shifts the gui through `SizeOffset` when its
`Size` has a pixel part.

## Hooks

Every hook gets a `Context` with the `Prompt`, its cloned `Gui` and the `InputType` it was shown for. A new context is
made each time a prompt is shown.

| Hook | Called |
|------|--------|
| `OnShown(context)` | after the gui is parented |
| `OnHidden(context)` | when the prompt hides, is disabled or is destroyed; the gui is destroyed after it returns, so it may yield for an exit animation |
| `OnHoldBegan(context)` | when the hold starts |
| `OnHoldEnded(context)` | when the hold is released or completes; reset the fill here |
| `OnProgress(context, alpha)` | every frame while held, with `alpha` going from 0 to 1 over `HoldDuration` |
| `OnTriggered(context)` | when the prompt triggers |
| `OnTriggerEnded(context)` | when the trigger ends |

Roblox still decides when a prompt shows (`MaxActivationDistance`, `RequiresLineOfSight`, `Exclusivity`), how long it
is held (`HoldDuration`) and which keys trigger it (`KeyboardKeyCode`, `GamepadKeyCode`).

## License

[MIT](LICENSE)
