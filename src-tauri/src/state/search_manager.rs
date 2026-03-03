use crate::models::note::Note;
use nucleo::{Config, Nucleo, pattern::CaseMatching, pattern::Normalization};

pub struct SearchManager;

impl SearchManager {
    pub fn search(notes: &[Note], query: &str) -> Vec<(Note, u32)> {
        if query.trim().is_empty() {
            // Return all notes sorted by modified date
            return notes.iter().map(|n| (n.clone(), 0)).collect();
        }

        let mut nucleo: Nucleo<usize> =
            Nucleo::new(Config::DEFAULT, std::sync::Arc::new(|| {}), None, 1);

        // Inject items
        let injector = nucleo.injector();
        for (i, note) in notes.iter().enumerate() {
            let search_text = format!("{} {}", note.title, note.content);
            let _ = injector.push(i, |_val, cols| {
                cols[0] = search_text.into();
            });
        }

        // Run the pattern matching
        nucleo.pattern.reparse(
            0,
            query,
            CaseMatching::Smart,
            Normalization::Smart,
            false,
        );

        // Tick until results are ready
        nucleo.tick(500);

        let snapshot = nucleo.snapshot();
        let mut results: Vec<(Note, u32)> = Vec::new();

        // Items are returned sorted by score (best first)
        for (rank, item) in snapshot
            .matched_items(..snapshot.matched_item_count())
            .enumerate()
        {
            let idx = *item.data;
            if idx < notes.len() {
                // Use inverse rank as score (higher = better match)
                let score = (snapshot.matched_item_count() - rank as u32) as u32;
                results.push((notes[idx].clone(), score));
            }
        }

        results
    }
}
