/**
 * Code block enhancements: copy button and format button overlays.
 * Uses prettier/standalone for formatting (loaded on demand).
 */

const LANG_TO_PRETTIER: Record<string, { parser: string; plugin: () => Promise<any> }> = {
  json: { parser: "json", plugin: () => import("prettier/plugins/babel") },
  js: { parser: "babel", plugin: () => import("prettier/plugins/babel") },
  javascript: { parser: "babel", plugin: () => import("prettier/plugins/babel") },
  ts: { parser: "typescript", plugin: () => import("prettier/plugins/typescript") },
  typescript: { parser: "typescript", plugin: () => import("prettier/plugins/typescript") },
  html: { parser: "html", plugin: () => import("prettier/plugins/html") },
  xml: { parser: "html", plugin: () => import("prettier/plugins/html") },
  css: { parser: "css", plugin: () => import("prettier/plugins/postcss") },
  scss: { parser: "scss", plugin: () => import("prettier/plugins/postcss") },
  less: { parser: "less", plugin: () => import("prettier/plugins/postcss") },
  md: { parser: "markdown", plugin: () => import("prettier/plugins/markdown") },
  markdown: { parser: "markdown", plugin: () => import("prettier/plugins/markdown") },
  yaml: { parser: "yaml", plugin: () => import("prettier/plugins/yaml") },
  yml: { parser: "yaml", plugin: () => import("prettier/plugins/yaml") },
};

async function formatCode(code: string, lang: string): Promise<string | null> {
  const config = LANG_TO_PRETTIER[lang];
  if (!config) return null;

  try {
    const [prettier, plugin] = await Promise.all([
      import("prettier/standalone"),
      config.plugin(),
    ]);
    // For babel parser, also need estree plugin
    const plugins = [plugin];
    if (config.parser === "babel" || config.parser === "json") {
      const estree = await import("prettier/plugins/estree");
      plugins.push(estree);
    }
    if (config.parser === "typescript") {
      const estree = await import("prettier/plugins/estree");
      plugins.push(estree);
    }

    const formatted = await prettier.format(code, {
      parser: config.parser,
      plugins,
      tabWidth: 2,
      printWidth: 80,
    });
    return formatted.trimEnd();
  } catch {
    return null;
  }
}

export function addCopyButtons(editorEl: HTMLDivElement): void {
  // Remove existing button containers
  editorEl.querySelectorAll(".code-block-buttons").forEach((el) => el.remove());

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
      const fenceLine = openFence.parentElement;
      if (!fenceLine) { i += 2; continue; }

      // Create button container div
      const btnContainer = document.createElement("div");
      btnContainer.className = "code-block-buttons";
      btnContainer.contentEditable = "false";

      // Detect language from the lang span sibling
      const langSpan = fenceLine.querySelector(".md-codeblock-lang");
      const lang = (langSpan?.textContent?.trim() || "").toLowerCase();

      // Format button (if language is supported)
      if (lang in LANG_TO_PRETTIER) {
        const fmtBtn = document.createElement("button");
        fmtBtn.className = "code-format-btn";
        fmtBtn.textContent = "Format";
        fmtBtn.onclick = async (e) => {
          e.preventDefault();
          e.stopPropagation();

          fmtBtn.textContent = "Formatting...";

          // Re-collect current code content (may have changed)
          let currentCode = "";
          let codeEl = fenceLine.nextElementSibling;
          while (codeEl && !codeEl.contains(closeFence) && !codeEl.classList.contains("code-block-buttons")) {
            const codeSpan = codeEl.querySelector(".md-codeblock-content");
            if (codeSpan) {
              if (currentCode) currentCode += "\n";
              currentCode += codeSpan.textContent || "";
            }
            codeEl = codeEl.nextElementSibling;
          }

          const formatted = await formatCode(currentCode, lang);
          if (formatted && formatted !== currentCode) {
            const codeLineEls: HTMLElement[] = [];
            let walkEl = fenceLine.nextElementSibling;
            while (walkEl && !walkEl.contains(closeFence) && !walkEl.classList.contains("code-block-buttons")) {
              const codeSpan = walkEl.querySelector(
                ".md-codeblock-content",
              ) as HTMLElement | null;
              if (codeSpan) {
                codeLineEls.push(codeSpan);
              }
              walkEl = walkEl.nextElementSibling;
            }

            const codeLines = formatted.split("\n");
            for (let idx = 0; idx < codeLines.length; idx++) {
              if (idx < codeLineEls.length) {
                codeLineEls[idx].textContent = codeLines[idx];
              }
            }
            for (let idx = codeLines.length; idx < codeLineEls.length; idx++) {
              codeLineEls[idx].textContent = "";
            }

            editorEl.dispatchEvent(new Event("input", { bubbles: true }));
            fmtBtn.textContent = "Formatted!";
            setTimeout(() => { fmtBtn.textContent = "Format"; }, 1500);
          } else if (formatted === null) {
            fmtBtn.textContent = "Error";
            setTimeout(() => { fmtBtn.textContent = "Format"; }, 1500);
          } else {
            fmtBtn.textContent = "No change";
            setTimeout(() => { fmtBtn.textContent = "Format"; }, 1500);
          }
        };
        btnContainer.appendChild(fmtBtn);
      }

      // Copy button
      const copyBtn = document.createElement("button");
      copyBtn.className = "code-copy-btn";
      copyBtn.textContent = "Copy";
      copyBtn.onclick = (e) => {
        e.preventDefault();
        e.stopPropagation();
        navigator.clipboard.writeText(codeContent);
        copyBtn.textContent = "Copied!";
        setTimeout(() => { copyBtn.textContent = "Copy"; }, 1500);
      };
      btnContainer.appendChild(copyBtn);

      // Insert button container before the closing fence line
      const closeFenceLine = closeFence.parentElement;
      if (closeFenceLine) {
        closeFenceLine.before(btnContainer);
      }
    }

    i += 2;
  }
}
