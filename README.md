# MacSwitch

Press **fn (🌐) + number** to switch the keyboard layout on macOS.

- `fn + 1` selects the first enabled layout, `fn + 2` the second, and so on up to `fn + 9`.
- A small 🌐 icon in the menu bar shows the key map. You can assign any layout to any key there.
- The menu also has a **Launch at login** switch and **Quit**.
- It uses the layouts you enabled in System Settings → Keyboard → Input Sources.

Requires macOS 13 or later (Apple Silicon and Intel).

## Install

1. Download `MacSwitch.zip` from the [Releases](../../releases) page and unzip it.
2. Move `MacSwitch.app` to `/Applications`.
3. Right-click the app and choose **Open**. Confirm the warning. The app is not notarized, so macOS asks once.
   If macOS still refuses, run `xattr -dr com.apple.quarantine /Applications/MacSwitch.app`.
4. Allow **Accessibility** access when macOS asks (System Settings → Privacy & Security → Accessibility).
   If `fn + number` does nothing, also allow **Input Monitoring**.
5. Click the 🌐 icon in the menu bar and turn on **Launch at login**.

After you update the app, macOS may ask for the permission again. Remove the old MacSwitch entry in the Accessibility list and add the app again.

## Layout order

By default `fn + 1` to `fn + 9` follow the order macOS gives. To change a key, open the menu, point at its `fn + N` row, and pick a layout. The choice is saved. **Reset to system order** removes your choices.

The menu reads the enabled layouts each time it opens, so a layout you add in System Settings shows up at once.

## Build from source

Needs Xcode command line tools.

```bash
./build.sh            # build/MacSwitch.app (universal)
./build.sh --install  # also copy to ~/Applications and start it
./build.sh --zip      # also create dist/MacSwitch.zip for a release
```

## How it works

A session event tap (`CGEventTap`) watches for a number key with the fn flag. It selects the layout with `TISSelectInputSource` and swallows the key press, so no digit is typed. Other fn combinations, such as fn + arrow, are not changed.

## License

[MIT](LICENSE)
