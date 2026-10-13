# Zinoos Hub

Client automation for Roblox **Lift Rock For Eggs** (Place ID `76731343328034`).

This hub trains on your own gym, grabs an eligible egg, and comes back. It does not sell pets, delete pets, or buy paid instant rock lifts.

## Load it

Latest `main`:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/yszvzms6st-pixel/ZinoosHub/main/ZinoosHub.luau"))()
```

Pin one commit when you want the script to stay on that version. Replace the hash with the commit you want. This example is an older snapshot:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/yszvzms6st-pixel/ZinoosHub/292de2c3b9746f286c7b6c80249a2c7b1c190e48/ZinoosHub.luau"))()
```

Running it again while the hub is already open does nothing. Unload first, then run the loader again.

## What it does

- Trains strength on the bench until rebirth has no next tier, then trains speed on the treadmill.
- Leaves training only for an egg in the selected zone that meets Alert Rarity. The fresh default is Divine, in the Prehistoric zone.
- Rebirths, buys gym upgrades and trails, claims the daily reward, and works through the index.
- Opens eggs when they are ready, and equips a better bag pet only when it earns more than the worst hatched pet on the plot.
- Can take the free stash, lighten pet visuals, and draw egg and inventory ESP.
- Low End lowers this session's graphics only. It does not change the saved Roblox quality setting.
- Sends a Discord message when an eligible egg appears, is stolen, or hatches.

A fresh save turns these on: Auto Train, Auto Rebirth, Auto Upgrade, Auto Trails, Auto Steal, Auto Open, Equip Best, Auto Daily, Auto Index, Free Stash, Lite Pets, Egg ESP, Inventory ESP, Low End, and Webhook Alerts. An existing configuration file is loaded and kept. Auto Sell stays off.

Press **Right Control** to open or close the menu. Drag the top bar or the sidebar to move the window. The Zinoos button can be dragged too.

## Saved configuration

The hub writes `Rayfield/Configurations/ZinoosHub/ZinoosHub.rfld` in the executor workspace.

That file stores the Discord webhook URL as plain text. Anyone who can read the executor workspace can read the URL. Do not share that file.

## Unload and reload

Unload stops this run, disconnects the connections it created, restores the methods and temporary changes it made, and removes the menu. Run the loader again after that. Webhooks, features, and Unload work on the new run. Repeating unload and reload does not stack menus, hooks, or callbacks.

## Executor

The script expects an executor that provides `request`, `filtergc`, `getupvalues`, `getconnections`, `fireproximityprompt`, `readfile`, and `writefile`. `request` is what Discord alerts use. If it is missing, the Test Webhook button says so instead of failing quietly.

## Rules

Automation can break the game's rules. It is not guaranteed to be ban safe. Use it at your own risk.
