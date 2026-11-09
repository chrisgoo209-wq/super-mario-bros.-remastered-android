# SMB2 fork: World 1-1 test level

Open it from the title screen: tap the **SMB2 TEST** button (top-left), or press **F2** on a keyboard.

## ROM
- Needs your own *Super Mario Bros. 2 (USA)* `.nes` ROM (262,160 bytes, MMC3). No Nintendo data is shipped.
- **Android:** the first time, the screen says *TAP THE SCREEN*. Tap it and pick your SMB2 `.nes` file. It is
  copied into the app's storage, so you only do this once (same idea as the SMB1 ROM screen).
- **PC:** drop the ROM on the window, put it next to the game executable, or pass `-smb2rom <path>`.
- If the ROM is the right size and type but its data check does not match, it is still accepted and the
  character screen shows a yellow "ROM NOT RECOGNISED" note. If the sprites look like noise, it is the wrong dump.

## Controls (touch)
- D-pad: move. **A**: jump (Peach: hold A in the air to float).
- **B**: pull a vegetable (stand on a grass tuft), pick up an enemy you are standing on, throw what you carry.
  Hold B to run (walk 1.5 px/frame, run 2.25 px/frame, as in the real game).
- **Super jump**: hold **Down** until the character flashes (about 1 second), then press A.
- **Up** on a vine: climb.
- **START**: leave the level and go back to the title screen.
- On the character screen, **B** opens the *sprite viewer*, a tool that shows the ROM's pose table and tiles
  so the poses can be mapped exactly.

## Building the Android APK without a PC
1. On GitHub open the **Actions** tab, choose **Android APK**, tap **Run workflow**.
2. When it turns green (about 10 to 20 minutes), open **Releases** and download `SMB1R-android.apk`.
3. Open the downloaded file on the phone and allow "install unknown apps" for your browser when asked.

## Status
- Level layout is original, built from a reference map. It is NOT read from the ROM.
- Player sprites come from the ROM at runtime. Tiles, enemies and items are placeholder art drawn in code.
- The SMB2 entry on the Select Game screen uses the box art tile you added to Assets/Sprites/UI/CampaignIcons.png.
- Tested headless in Godot 4.5 with a synthetic ROM (select, play, die, retry, game over, wide-screen layout).
  Not yet tested on a real phone or with a real SMB2 ROM.
