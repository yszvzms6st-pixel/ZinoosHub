# Zinoos Hub

Client automation for Roblox. One loadstring works in every supported game:

| Game | Hub file |
|---|---|
| **Lift Rock For Eggs** (Place ID `76731343328034`) | `games/LiftRock.luau` |
| **Deep Fishing** (Game ID `10526853622`) | `games/DeepFishing.luau` |

## Load it

Latest `main`:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/yszvzms6st-pixel/ZinoosHub/main/ZinoosHub.luau"))()
```

`ZinoosHub.luau` is a small loader. It checks which game you are in and loads that game's hub from `games/`. In a game that is not on the list it prints a warning and does nothing.

Pin one commit when you want a game's hub to stay on that version. Load the file under `games/` at that commit directly. Replace the hash with the commit you want:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/yszvzms6st-pixel/ZinoosHub/<commit>/games/LiftRock.luau"))()
```

Commits from before the loader existed kept the Lift Rock hub in `ZinoosHub.luau`, so an older pinned link still works.

## Deep Fishing

Uses the same window as the Lift Rock hub. Pages: Home, Fishing, Economy, Enchant, Webhooks, Player and Settings. Anything that walks you away from the water waits for the current cast to finish and brings you back.

**Fishing**

- **Auto Fish** turns on the game's own auto fishing, including below its Level 5 unlock. If you leave the water it puts you back at your fishing spot.
- **Auto Perfect Fishing** lands Perfect throws at the **Perfect Chance** you set, with the shorter waits of the AutoBoost enchant.
- **Fast Reel Animation** skips the rare catch showcase. **Game Double Speed** turns on the game's own 1.5x speed, which needs the group. **Fast Win Rare Fights** clicks fights at the game's 12 clicks a second cap.
- **Auto Collect Fish** grabs fish straight from the school while the hook window is open, up to your hook capacity. **Collect Rarities** and **Collect Mutations** pick which ones; nothing ticked takes everything. **Auto Stop When Empty** reels in once nothing you want is left.
- **Auto Collect Finds** grabs finds in the water, filtered by **Find Types**.
- **Auto Claim Big Fish** walks to the Next Day Reward and claims the big fish once it reads Claim!. **Auto Claim Free Rewards** claims the playtime gift, daily rewards, the daily free claim, the group reward and achievements. **Auto Feed Big Mouth** feeds it your cheapest plain fish until it is full, and is off by default because it uses those fish up.
- **Redeem All Codes** tries every known code you have not redeemed, plus any **Extra Codes**. **Code** redeems one.

**Economy**

- **Auto Sell All Fish** sells at **Sell When Fish Count**, and **Auto Sell When Inventory Full** sells when the bag is capped. With **Sell Rarities** or **Sell Mutations** ticked it sells only matching fish, one at a time by id, so a fish you keep is never sent. **Rarity + Mutation Match** is Either or Both. **Sell Filtered Fish** and **Sell All Fish** run it now. Favorited fish are never sold.
- **Auto Favorite Fish** favorites fish matching **Favorite Rarities** and **Favorite Mutations**, a few at a time, since the game drops big bursts. **Game Auto Favorite** sets the game's own setting.
- **Auto Buy Best Bait** buys the luckiest bait you can afford here when you run out. **Auto Buy Best Rod** buys and equips the strongest rod you can afford, skipping event, Maze, Cave and Volcano rods. **Auto Buy Upgrades** buys the cheapest ticked upgrade; nothing ticked buys any.
- **Auto Use Best Bait** and **Auto Use Bait** put bait on whenever none is on. Each has a Now button.

**Enchant**

- **Auto Enchant** holds the picked **Stone** at the Enchant Shrine and rolls, waiting **Delay Between Rolls**, until one of the **Stop On Enchants** lands or the stones run out. The shrine is not in World 1.
- **Auto Reroll Held Fish** spins the fish you are holding at the Mutation Dealer until one of the **Stop On Mutations** lands or the scrolls run out. **Use Ultra Scrolls** and **Skip Animation** work like the dealer's own buttons. Fishing waits while this is on.

**Webhooks** posts catches that match **Catch Rarities** or **Catch Mutations** to a Discord webhook, and optionally each sale and an hourly report.

**Player** has WalkSpeed, Jump Power, Infinite Jump, Noclip, **Teleport To** for the NPCs in this world, and **Travel To World** for worlds you have unlocked.

**Settings** has Hub Size, Anti AFK, Auto-load on Rejoin and Unload.

Settings save per account to `Rayfield/Configurations/ZinoosHub/DeepFishing_<UserId>.rfld`. Right Control opens and closes the menu.

## Lift Rock For Eggs

This hub trains on your own gym, grabs an eligible egg, and comes back. It does not sell pets, delete pets, or buy paid instant rock lifts.

Running it again replaces the hub that is already open. The new run stops the previous loops, disconnects its connections, puts back temporary bench, prompt, collision and purchase-pad changes, and removes the old menu before it starts. Saved Low End and Lite Pets stay as they were. The original graphics settings are remembered from the first load and are not recaptured while Low End is on.

### What it does

- Trains strength on the bench until rebirth has no next tier, then trains speed on the treadmill.
- Leaves training only for the eligible egg that earns the most in the ticked zones. Abyssal, Crabby, and Cursed eggs come before a plain egg of the same rarity. It checks every ticked zone during the day, then goes again two seconds after a pickup. Pearls are saved for Trench Eggs. The fresh default is Divine, in the Meadow zone. An old save that still has the automatic Prehistoric zone is moved to Meadow once. Zones you pick yourself are kept, and you can tick more than one. Abyss is one of the zones you can pick.
- Auto Trench is a switch. When it is on, the hub leaves the bench for the seal, keeps lifting until the rift opens, then stops holding you so the game can pull you in. Inside, it lifts the strongest pinned tentacle you can actually move and taps out of a grab. A Crown tentacle heavier than your strength is left alone. Trench Shop is its own switch and spends pearls on Trench Eggs only. It does not buy Robux rift skips, pearl packs, or paid boosts.
- Home has an Activity card. It shows the countdown until the next Trench, whether you are heading to the rift, lifting the seal, or in the fight, how many pearls you have, and the latest gym, floor, trail, daily, index, stash, and shop actions.
- Rebirths, buys gym upgrades and trails, claims the daily reward, and works through the index.
- Opens eggs when they are ready, and equips a better bag pet only when it earns more than the worst hatched pet on the plot. A failed swap puts that same pet back on its old spot.
- Custom theme colours still apply when a picture URL is rejected. Theme pictures are downloaded only from `ysoyjfnigavjajrjftmv.supabase.co`.
- Can take the free stash, lighten pet visuals, and draw egg and inventory ESP.
- Low End lowers this session's graphics only. It does not change the saved Roblox quality setting.
- Sends a Discord message when an eligible egg matching the selected rarity appears, is stolen, or hatches.
- Anti AFK keeps the session in the game while you are idle. It tries VirtualUser first, then VirtualInputManager, and pulses again every eight minutes. It does not move the character, leave the bench, or press anything on screen. If neither input method exists, the switch stays on and the tracker says Anti AFK is unavailable. The eight-minute gap matches the idle pulse in the script.

A fresh save turns these on: Auto Train, Anti AFK, Auto Rebirth, Auto Upgrade, Auto Trails, Auto Steal, Auto Trench, Trench Shop, Auto Open, Equip Best, Auto Daily, Auto Index, Free Stash, Lite Pets, Egg ESP, Inventory ESP, Low End, and Webhook Alerts. An existing configuration file is loaded once at startup and kept. Saved toggles, the webhook URL, menu position, and rarity stay as they were. A missing zone, or an old automatic Prehistoric zone, becomes Meadow until you choose a zone. Auto Sell stays off.

Press **Right Control** to open or close the menu. Drag the top bar or the sidebar to move the window. The Zinoos button can be dragged too.

### Saved configuration

The hub writes one file per account:

`Rayfield/Configurations/ZinoosHub/ZinoosHub_<UserId>.rfld`

`<UserId>` is your Roblox user id. If that id is missing, it falls back to:

`Rayfield/Configurations/ZinoosHub/ZinoosHub.rfld`

Both paths are in the executor workspace. The file stores the Discord webhook URL as plain text. Anyone who can read the executor workspace can read the URL. Do not share that file. The webhook box in the menu is hidden until you press Show webhook. Hiding the box does not encrypt the file.

### Unload and reload

Unload stops this run, disconnects the connections it created, restores the methods and temporary changes it made, puts pet visuals and the original graphics back, and removes the menu and the inventory HUD. A second Unload does nothing harmful. Run the loader again after that. The next load can remember a fresh graphics baseline. Webhooks, features, and Unload work on the new run. Repeating unload and reload does not stack menus, heartbeats, hooks, or inventory HUDs.

Search covers Home, Main, and Discord. A result on another page opens that page. Clearing the search shows the page contents again.

If a game update removes something one feature needs, that feature turns off and names the missing piece. The rest of the hub keeps running. The next load tries the feature again.

## Executor

The script expects an executor that provides `request`, `filtergc`, `getupvalues`, `getconnections`, `fireproximityprompt`, `readfile`, and `writefile`. `request` is what Discord alerts use. If it is missing, the Test Webhook button says so instead of failing quietly.

## Rules

Automation can break the game's rules. It is not guaranteed to be ban safe. Use it at your own risk.
