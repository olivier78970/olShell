## IPC

Bind these to keys, e.g. from Hyprland:

```sh
quickshell -p . ipc call wallpapers wallpapersToggle   # open/close the wallpaper panel
quickshell -p . ipc call wallpapers applyPod           # apply the Bing picture of the day
quickshell -p . ipc call wallpapers applyRandom        # apply a random wallpaper other than the current one
quickshell -p . ipc call wallpapers applyLast          # apply the last applied wallpaper again (e.g. after a new picture of the day was downloaded)
quickshell -p . ipc call launcher toggle               # open/close the application launcher
quickshell -p . ipc call shortcuts toggle              # open/close the keyboard shortcuts panel
quickshell -p . ipc call chatai toggle                 # open/close the chat AI panel
quickshell -p . ipc call chatai ask "<question>"       # open it and ask (also: cancel, clear, answer, providers, select <id>, selectModel <id> <model>, selectDefault)
quickshell -p . ipc call switcher toggle               # open the app switcher, or move on while open (also: next, prev, confirm, close)
quickshell -p . ipc call settings toggle               # open/close the settings panel
quickshell -p . ipc call profiles apply "<name>"       # switch to a saved configuration (also: list, save "<name>", remove "<name>")
quickshell -p . ipc call webApps open "<name>"         # open a web app (also: list)
quickshell -p . ipc call notifications toggle          # open/close the notification center
quickshell -p . ipc call clock toggle                  # open/close the clock panel (on the focused screen)
quickshell -p . ipc call weather now                   # the clock panel's weather as JSON (also: refresh)
quickshell -p . ipc call notifications dnd 1           # do not disturb on (0: off); also toggleDnd, clear, count
quickshell -p . ipc call themes themesToggle       # open/close the theme panel
quickshell -p . ipc call lock lock                # lock the screen (`lock status` prints 1 while locked)
quickshell -p . ipc call power toggle              # open/close the power panel
quickshell -p . ipc call power logout              # ask to confirm logging out (also: restart, shutdown, firmware for the UEFI setup)
quickshell -p . ipc call power suspend             # suspend at once, with no confirmation
quickshell -p . ipc call volume increase 0.05
quickshell -p . ipc call volume decrease 0.05
quickshell -p . ipc call volume mute
quickshell -p . ipc call zoom zoomIn               # zoom the screen in by the zoom step (zoomOut: out; zoomInBy <step>, zoomOutBy <step>: by a step of its own)
quickshell -p . ipc call zoom set 2                # zoom to a factor, 1 being none (`zoom get` prints it, `zoom reset` goes back to 1)
```

Volume changes from any source (these calls, media keys, pavucontrol...) also show the OSD.
