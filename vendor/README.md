# vendor/ (offline cache)

This directory holds **regenerated** offline assets. They are **gitignored** except this README.

```bash
../scripts/10-fetch-offline.sh
../scripts/20-sync-app.sh
```

| Subdir | Purpose |
|--------|---------|
| `debs/` | Ubuntu `.deb` packages |
| `wheels/` | Python wheels |
| `models/` | MediaPipe `.task` |
| `sls-camera/` | App tree at pinned commit |

Do **not** store Microsoft Kinect UAC firmware files here in a public clone.
