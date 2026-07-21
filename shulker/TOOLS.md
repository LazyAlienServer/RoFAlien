# ShulkerRDK toolchain

The local binaries are pinned official release assets from
[LiPolymer/ShulkerRDK](https://github.com/LiPolymer/ShulkerRDK). They are not
committed to this repository. Install or verify them on Windows with:

```powershell
.\shulker\install.ps1
```

| File | Release | SHA-256 |
| --- | --- | --- |
| `srdk.exe` | `B0.15` | `d78d89b955e37d979a879402bd766af3d2b60c7d25f9b7c44da07900c0f9f6e8` |
| `shulker/extensions/ShulkerRDK.Aseprite.dll` | `B0.15` | `c84db27090410791e1a03ca7d70c51a3f01d9f5a9e304a5ad5551606ec238cb6` |

The installer checks every asset before use and refuses a mismatched download.
The core and extension intentionally use the same release. The build does not
install ResourceMagick or ShulkerRRT because this repository currently needs
neither PSD conversion nor Minecraft hot reload. ShulkerRDK is distributed
under GPL-3.0; its source and license are available from the upstream link.
