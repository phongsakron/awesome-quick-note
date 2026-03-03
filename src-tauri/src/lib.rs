#![allow(unexpected_cfgs)]

pub mod commands;
pub mod models;
pub mod state;

use commands::{git_sync, image, pin, search, settings, shortcuts, vault, window};
use state::{
    git_sync_manager::GitSyncManager, pin_manager::PinManager,
    recent_manager::RecentManager, settings_manager::SettingsManager,
    vault_manager::VaultManager,
};
use std::path::PathBuf;
use std::sync::Arc;
use tauri::{
    menu::{Menu, MenuItem},
    tray::TrayIconBuilder,
    Emitter, Manager,
};

#[cfg(target_os = "macos")]
use tauri::ActivationPolicy;

fn setup_file_watcher(
    vault_path: PathBuf,
    app_handle: tauri::AppHandle,
    git_sync: Arc<GitSyncManager>,
) {
    use notify::{Config, RecommendedWatcher, RecursiveMode, Watcher, Event};
    use std::sync::mpsc;

    std::thread::spawn(move || {
        let (tx, rx) = mpsc::channel::<Result<Event, notify::Error>>();
        let mut watcher = match RecommendedWatcher::new(tx, Config::default()) {
            Ok(w) => w,
            Err(_) => return,
        };

        if watcher.watch(&vault_path, RecursiveMode::NonRecursive).is_err() {
            return;
        }

        for result in rx {
            if let Ok(event) = result {
                use notify::EventKind;
                match event.kind {
                    EventKind::Create(_) | EventKind::Modify(_) | EventKind::Remove(_) => {
                        let _ = app_handle.emit("vault:notes-changed", ());
                        git_sync.notify_file_changed();
                    }
                    _ => {}
                }
            }
        }
    });
}

pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_global_shortcut::Builder::new().build())
        .plugin(tauri_plugin_fs::init())
        .setup(|app| {
            #[cfg(target_os = "macos")]
            app.set_activation_policy(ActivationPolicy::Accessory);

            let config_dir = app
                .path()
                .app_config_dir()
                .unwrap_or_else(|_| PathBuf::from("."));

            let settings_manager = SettingsManager::new(config_dir.clone());
            let vault_manager = VaultManager::new();
            let pin_manager = PinManager::new(config_dir.clone());
            let recent_manager = RecentManager::new(config_dir);
            let git_sync_manager = Arc::new(GitSyncManager::new());

            // Restore vault from settings
            if let Some(vault_path) = settings_manager.vault_path() {
                let path = PathBuf::from(&vault_path);
                if path.exists() {
                    vault_manager.set_vault(path.clone());

                    // Set up git sync
                    if settings_manager.get().git_sync_enabled {
                        git_sync_manager.set_enabled(true, app.handle());
                    }

                    // Start file watcher
                    setup_file_watcher(
                        path,
                        app.handle().clone(),
                        Arc::clone(&git_sync_manager),
                    );
                }
            }

            // Start git sync background tasks
            git_sync_manager.start_background_tasks(app.handle().clone());

            // Build system tray
            let show_hide = MenuItem::with_id(app, "show_hide", "Show/Hide", true, None::<&str>)?;
            let quit = MenuItem::with_id(app, "quit", "Quit", true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&show_hide, &quit])?;

            TrayIconBuilder::new()
                .icon(app.default_window_icon().unwrap().clone())
                .menu(&menu)
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "show_hide" => {
                        if let Some(window) = app.get_webview_window("main") {
                            if window.is_visible().unwrap_or(false) {
                                let _ = window.hide();
                            } else {
                                let _ = window.show();
                                let _ = window.set_focus();
                            }
                        }
                    }
                    "quit" => {
                        app.exit(0);
                    }
                    _ => {}
                })
                .build(app)?;

            // Manage state
            app.manage(settings_manager);
            app.manage(vault_manager);
            app.manage(pin_manager);
            app.manage(recent_manager);
            app.manage(git_sync_manager);

            // macOS: Set window to join all spaces
            #[cfg(target_os = "macos")]
            {
                extern crate objc;
                use objc::{msg_send, sel, sel_impl};

                if let Some(window) = app.get_webview_window("main") {
                    if let Ok(ns_window) = window.ns_window() {
                        unsafe {
                            // NSWindowCollectionBehaviorCanJoinAllSpaces (1 << 0)
                            // | NSWindowCollectionBehaviorFullScreenAuxiliary (1 << 8)
                            let behavior: u64 = (1 << 0) | (1 << 8);
                            let _: () = msg_send![ns_window as *mut objc::runtime::Object, setCollectionBehavior: behavior];
                        }
                    }
                }
            }

            // Restore panel position from settings (logical coordinates)
            {
                let settings_mgr: tauri::State<SettingsManager> = app.state();
                let s = settings_mgr.get();
                if let (Some(x), Some(y)) = (s.panel_x, s.panel_y) {
                    if let Some(window) = app.get_webview_window("main") {
                        let _ = window.set_position(tauri::Position::Logical(
                            tauri::LogicalPosition::new(x as f64, y as f64),
                        ));
                    }
                }
            }

            // Register global shortcuts
            shortcuts::register_shortcuts(app.handle().clone()).ok();

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            vault::select_vault,
            vault::set_vault,
            vault::get_vault_path,
            vault::get_notes,
            vault::create_note,
            vault::create_vault,
            vault::save_note,
            vault::delete_note,
            vault::record_note_opened,
            search::search_notes,
            git_sync::get_git_sync_status,
            git_sync::manual_sync,
            git_sync::set_git_sync_enabled,
            settings::get_settings,
            settings::update_settings,
            settings::get_platform_info,
            image::save_image,
            image::copy_image_to_clipboard,
            image::open_file,
            pin::toggle_pin,
            pin::get_pinned_notes,
            shortcuts::register_shortcuts,
            window::get_window_position,
            window::set_window_position,
            window::get_screen_bounds,
            window::reveal_in_file_manager,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
