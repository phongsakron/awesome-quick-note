use tauri::{AppHandle, Manager};
use serde::Serialize;

#[derive(Serialize)]
pub struct WindowPosition {
    pub x: i32,
    pub y: i32,
}

#[derive(Serialize)]
pub struct ScreenBounds {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
    pub scale_factor: f64,
}

#[tauri::command]
pub fn get_window_position(app: AppHandle) -> Result<WindowPosition, String> {
    let window = app.get_webview_window("main").ok_or("Window not found")?;
    let pos = window.outer_position().map_err(|e| e.to_string())?;
    Ok(WindowPosition { x: pos.x, y: pos.y })
}

#[tauri::command]
pub fn set_window_position(x: f64, y: f64, app: AppHandle) -> Result<(), String> {
    let window = app.get_webview_window("main").ok_or("Window not found")?;
    window
        .set_position(tauri::Position::Logical(tauri::LogicalPosition::new(x, y)))
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub fn get_screen_bounds(app: AppHandle) -> Result<ScreenBounds, String> {
    let window = app.get_webview_window("main").ok_or("Window not found")?;
    let monitor = window
        .current_monitor()
        .map_err(|e| e.to_string())?
        .ok_or("No monitor found")?;
    let scale = monitor.scale_factor();
    let pos = monitor.position();
    let size = monitor.size();
    // Return logical coordinates (physical / scale_factor)
    Ok(ScreenBounds {
        x: pos.x as f64 / scale,
        y: pos.y as f64 / scale,
        width: size.width as f64 / scale,
        height: size.height as f64 / scale,
        scale_factor: scale,
    })
}

#[tauri::command]
pub fn reveal_in_file_manager(path: String) -> Result<(), String> {
    #[cfg(target_os = "macos")]
    {
        std::process::Command::new("open")
            .args(["-R", &path])
            .spawn()
            .map_err(|e| e.to_string())?;
    }
    #[cfg(target_os = "linux")]
    {
        std::process::Command::new("xdg-open")
            .arg(
                std::path::Path::new(&path)
                    .parent()
                    .unwrap_or(std::path::Path::new(&path)),
            )
            .spawn()
            .map_err(|e| e.to_string())?;
    }
    Ok(())
}
