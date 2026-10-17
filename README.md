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

Running it again replaces the hub that is already open. The new run stops the previous loops, disconnects its connections, puts back temporary bench, prompt, collision and purchase-pad changes, and removes the old menu before it starts. Saved Low End and Lite Pets stay as they were. The original graphics settings are remembered from the first load and are not recaptured while Low End is on.

## What it does

- Trains strength on the bench until rebirth has no next tier, then trains speed on the treadmill.
- Leaves training only for an eligible egg matching the selected rarity in the ticked zones. The fresh default is Divine, in the Meadow zone. An old save that still has the automatic Prehistoric zone is moved to Meadow once. Zones you pick yourself are kept, and you can tick more than one. Abyss is one of the zones you can pick.
- Joins the free Trench when the rift seal is up or the arena is open. It lifts the seal and pinned tentacles, taps out of a grab, and spends pearls on Trench Eggs. It does not buy Robux rift skips, pearl packs, or paid boosts.
- Rebirths, buys gym upgrades and trails, claims the daily reward, and works through the index.
- Opens eggs when they are ready, and equips a better bag pet only when it earns more than the worst hatched pet on the plot. A failed swap puts that same pet back on its old spot.
- Custom theme colours still apply when a picture URL is rejected. Theme pictures are downloaded only from `ysoyjfnigavjajrjftmv.supabase.co`.
- Can take the free stash, lighten pet visuals, and draw egg and inventory ESP.
- Low End lowers this session's graphics only. It does not change the saved Roblox quality setting.
- Sends a Discord message when an eligible egg matching the selected rarity appears, is stolen, or hatches.
- Anti AFK keeps the session in the game while you are idle. It tries VirtualUser first, then VirtualInputManager, and pulses again every eight minutes. It does not move the character, leave the bench, or press anything on screen. If neither input method exists, the switch stays on and the tracker says Anti AFK is unavailable. The eight-minute gap matches the idle pulse in the script.

A fresh save turns these on: Auto Train, Anti AFK, Auto Rebirth, Auto Upgrade, Auto Trails, Auto Steal, Auto Open, Equip Best, Auto Daily, Auto Index, Free Stash, Lite Pets, Egg ESP, Inventory ESP, Low End, and Webhook Alerts. An existing configuration file is loaded once at startup and kept. Saved toggles, the webhook URL, menu position, and rarity stay as they were. A missing zone, or an old automatic Prehistoric zone, becomes Meadow until you choose a zone. Auto Sell stays off.

Press **Right Control** to open or close the menu. Drag the top bar or the sidebar to move the window. The Zinoos button can be dragged too.

## Saved configuration

The hub writes one file per account:

`Rayfield/Configurations/ZinoosHub/ZinoosHub_<UserId>.rfld`

`<UserId>` is your Roblox user id. If that id is missing, it falls back to:

`Rayfield/Configurations/ZinoosHub/ZinoosHub.rfld`

Both paths are in the executor workspace. The file stores the Discord webhook URL as plain text. Anyone who can read the executor workspace can read the URL. Do not share that file. The webhook box in the menu is hidden until you press Show webhook. Hiding the box does not encrypt the file.

## Unload and reload

Unload stops this run, disconnects the connections it created, restores the methods and temporary changes it made, puts pet visuals and the original graphics back, and removes the menu and the inventory HUD. A second Unload does nothing harmful. Run the loader again after that. The next load can remember a fresh graphics baseline. Webhooks, features, and Unload work on the new run. Repeating unload and reload does not stack menus, heartbeats, hooks, or inventory HUDs.

Search covers Home, Main, and Discord. A result on another page opens that page. Clearing the search shows the page contents again.

If a game update removes something one feature needs, that feature turns off and names the missing piece. The rest of the hub keeps running. The next load tries the feature again.

## Executor

The script expects an executor that provides `request`, `filtergc`, `getupvalues`, `getconnections`, `fireproximityprompt`, `readfile`, and `writefile`. `request` is what Discord alerts use. If it is missing, the Test Webhook button says so instead of failing quietly.

## Rules

Automation can break the game's rules. It is not guaranteed to be ban safe. Use it at your own risk.
