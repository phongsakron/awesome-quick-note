/**
 * Code block enhancements: copy button and format button overlays.
 */

const FORMATTABLE_LANGS = new Set([
  "json",
  "xml",
  "html",
  "js",
  "javascript",
  "ts",
  "typescript",
]);

function formatCode(code: string, lang: string): string | null {
  try {
    if (lang === "json") {
      return JSON.stringify(JSON.parse(code), null, 2);
    }
    if (lang === "xml" || lang === "html") {
      return formatXml(code);
    }
    // For JS/TS, try JSON parse as best-effort
    if (["js", "javascript", "ts", "typescript"].includes(lang)) {
      return JSON.stringify(JSON.parse(code), null, 2);
    }
  } catch {
    return null;
  }
  return null;
}

function formatXml(xml: string): string {
  let formatted = "";
  let indent = 0;
  const parts = xml.replace(/(>)(<)/g, "$1\n$2").split("\n");
  for (const part of parts) {
    const trimmed = part.trim();
    if (!trimmed) continue;
    if (trimmed.startsWith("</")) indent--;
    formatted += "  ".repeat(Math.max(0, indent)) + trimmed + "\n";
    if (
      trimmed.startsWith("<") &&
      !trimmed.startsWith("</") &&
      !trimmed.endsWith("/>") &&
      !trimmed.includes("</")
    ) {
      indent++;
    }
  }
  return formatted.trimEnd();
}

export function addCopyButtons(editorEl: HTMLDivElement): void {
  // Remove existing copy and format buttons
  editorEl.querySelectorAll(".code-copy-btn").forEach((btn) => btn.remove());
  editorEl.querySelectorAll(".code-format-btn").forEach((btn) => btn.remove());

  // Find code block fences and add copy buttons
  const fences = editorEl.querySelectorAll(".md-codeblock-fence");
  let i = 0;
  while (i < fences.length - 1) {
    const openFence = fences[i] as HTMLElement;
    const closeFence = fences[i + 1] as HTMLElement;

    // Collect code content between fences
    let codeContent = "";
    let el = openFence.parentElement?.nextElementSibling;
    while (el && !el.contains(closeFence)) {
      const codeSpan = el.querySelector(".md-codeblock-content");
      if (codeSpan) {
        if (codeContent) codeContent += "\n";
        codeContent += codeSpan.textContent || "";
      }
      el = el.nextElementSibling;
    }

    if (codeContent) {
      const btn = document.createElement("button");
      btn.className = "code-copy-btn";
      btn.textContent = "Copy";
      btn.contentEditable = "false";
      btn.onclick = (e) => {
        e.preventDefault();
        e.stopPropagation();
        navigator.clipboard.writeText(codeContent);
        btn.textContent = "Copied!";
        setTimeout(() => {
          btn.textContent = "Copy";
        }, 1500);
      };

      // Position relative to the opening fence line
      const fenceLine = openFence.parentElement;
      if (fenceLine) {
        fenceLine.style.position = "relative";
        fenceLine.appendChild(btn);
      }

      // Detect language and add format button if supported
      const fenceText = openFence.textContent?.trim() || "";
      const langMatch = fenceText.match(/^```(\w+)/);
      const lang = langMatch ? langMatch[1].toLowerCase() : "";

      if (FORMATTABLE_LANGS.has(lang)) {
        const fmtBtn = document.createElement("button");
        fmtBtn.className = "code-format-btn";
        fmtBtn.textContent = "Format";
        fmtBtn.contentEditable = "false";
        fmtBtn.onclick = (e) => {
          e.preventDefault();
          e.stopPropagation();
          // Re-collect current code content (may have changed)
          let currentCode = "";
          let codeEl = openFence.parentElement?.nextElementSibling;
          while (codeEl && !codeEl.contains(closeFence)) {
            const codeSpan = codeEl.querySelector(".md-codeblock-content");
            if (codeSpan) {
              if (currentCode) currentCode += "\n";
              currentCode += codeSpan.textContent || "";
            }
            codeEl = codeEl.nextElementSibling;
          }

          const formatted = formatCode(currentCode, lang);
          if (formatted && formatted !== currentCode) {
            // Replace code content in editor elements
            // First, collect existing code line elements
            const codeLineEls: HTMLElement[] = [];
            let walkEl = openFence.parentElement?.nextElementSibling;
            while (walkEl && !walkEl.contains(closeFence)) {
              const codeSpan = walkEl.querySelector(
                ".md-codeblock-content",
              ) as HTMLElement | null;
              if (codeSpan) {
                codeLineEls.push(codeSpan);
              }
              walkEl = walkEl.nextElementSibling;
            }

            const codeLines = formatted.split("\n");
            // Update existing lines and add/remove as needed
            for (let idx = 0; idx < codeLines.length; idx++) {
              if (idx < codeLineEls.length) {
                codeLineEls[idx].textContent = codeLines[idx];
              }
            }
            // If formatted has fewer lines, clear extra lines
            for (let idx = codeLines.length; idx < codeLineEls.length; idx++) {
              codeLineEls[idx].textContent = "";
            }

            // Trigger input event so editor picks up changes
            editorEl.dispatchEvent(new Event("input", { bubbles: true }));
            fmtBtn.textContent = "Formatted!";
            setTimeout(() => {
              fmtBtn.textContent = "Format";
            }, 1500);
          } else if (formatted === null) {
            fmtBtn.textContent = "Error";
            setTimeout(() => {
              fmtBtn.textContent = "Format";
            }, 1500);
          } else {
            fmtBtn.textContent = "No change";
            setTimeout(() => {
              fmtBtn.textContent = "Format";
            }, 1500);
          }
        };

        const fmtFenceLine = openFence.parentElement;
        if (fmtFenceLine) {
          fmtFenceLine.appendChild(fmtBtn);
        }
      }
    }

    i += 2;
  }
}
