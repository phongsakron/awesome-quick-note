import { check } from "@tauri-apps/plugin-updater";
import { relaunch } from "@tauri-apps/plugin-process";
import { ask, message } from "@tauri-apps/plugin-dialog";

export async function checkForUpdates(silent: boolean): Promise<void> {
  try {
    const update = await check();

    if (update) {
      const confirmed = await ask(
        `A new version (${update.version}) is available. Would you like to update now?`,
        { title: "Update Available", kind: "info" }
      );

      if (confirmed) {
        await update.downloadAndInstall();
        await relaunch();
      }
    } else if (!silent) {
      await message("You're on the latest version.", {
        title: "No Updates",
        kind: "info",
      });
    }
  } catch (e) {
    if (!silent) {
      await message(`Failed to check for updates: ${e}`, {
        title: "Update Error",
        kind: "error",
      });
    }
  }
}
