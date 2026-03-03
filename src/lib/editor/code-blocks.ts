/**
 * Code block enhancements: copy button overlay.
 */

export function addCopyButtons(editorEl: HTMLDivElement): void {
  // Remove existing copy buttons
  editorEl.querySelectorAll(".code-copy-btn").forEach((btn) => btn.remove());

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
    }

    i += 2;
  }
}
