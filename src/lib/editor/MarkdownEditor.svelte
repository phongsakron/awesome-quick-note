<script lang="ts">
  import { onMount, tick } from "svelte";
  import { highlightMarkdown } from "./highlighter";
  import { handleListContinuation } from "./list-continuation";
  import { handleCheckboxClick } from "./checkbox-toggle";
  import { handleImagePaste, handleImageDrop } from "./image-paste";
  import { handleLinkClick } from "./link-handler";
  import { addCopyButtons } from "./code-blocks";
  import { updateImageOverlays } from "./image-overlay";
  import {
    createFindState,
    findMatches,
    replaceOne,
    replaceAll as replaceAllFn,
    type FindState,
  } from "./find-replace";
  import { settings } from "../stores/settings";

  interface Props {
    content: string;
    vaultPath: string | null;
    shouldFocus: boolean;
    onContentChange: (content: string) => void;
  }

  let { content, vaultPath, shouldFocus, onContentChange }: Props = $props();
  let editorEl: HTMLDivElement | undefined = $state();
  let findState = $state<FindState>(createFindState());
  let findInputEl: HTMLInputElement | undefined = $state();
  let lastContent = "";

  // Undo/redo stack
  interface UndoEntry {
    text: string;
    cursor: number;
  }
  let undoStack: UndoEntry[] = [];
  let redoStack: UndoEntry[] = [];
  const MAX_UNDO = 200;

  function pushUndo(text: string, cursor: number): void {
    // Don't push if identical to top of stack
    if (undoStack.length > 0 && undoStack[undoStack.length - 1].text === text) return;
    undoStack.push({ text, cursor });
    if (undoStack.length > MAX_UNDO) undoStack.shift();
    redoStack = [];
  }

  function applyEdit(newText: string, newCursor: number): void {
    lastContent = newText;
    if (editorEl) {
      renderHighlightedContent(editorEl, newText);
      setCursorOffset(editorEl, newCursor);
    }
    onContentChange(newText);
  }

  // Collect line divs (excluding image overlays, button containers, and other non-content elements)
  function getLineDivs(el: HTMLDivElement): HTMLElement[] {
    const divs: HTMLElement[] = [];
    for (const child of el.children) {
      if (
        child.tagName === "DIV" &&
        !child.classList.contains("image-overlay") &&
        !child.classList.contains("code-block-buttons")
      ) {
        divs.push(child as HTMLElement);
      }
    }
    return divs;
  }

  // Get text offset for a specific DOM point, properly counting \n between line divs
  function getOffsetForPoint(
    el: HTMLDivElement,
    container: Node,
    containerOffset: number,
  ): number {
    const lineDivs = getLineDivs(el);
    let offset = 0;

    for (let i = 0; i < lineDivs.length; i++) {
      if (i > 0) offset += 1; // newline between lines
      const lineDiv = lineDivs[i];

      if (lineDiv.contains(container) || lineDiv === container) {
        // Check if cursor is inside a non-editable element (e.g. Copy button)
        let node: Node | null = container;
        while (node && node !== lineDiv) {
          if (node.nodeType === Node.ELEMENT_NODE && (node as HTMLElement).contentEditable === "false") {
            // Cursor is in a button overlay; treat as end of line text
            offset += getTextContentWithoutOverlays(lineDiv).length;
            return offset;
          }
          node = node.parentNode;
        }
        const subRange = document.createRange();
        subRange.selectNodeContents(lineDiv);
        subRange.setEnd(container, containerOffset);
        offset += subRange.toString().length;
        return offset;
      }

      offset += getTextContentWithoutOverlays(lineDiv).length;
    }

    return offset;
  }

  // Save cursor position (text offset including \n characters)
  function getCursorOffset(el: HTMLDivElement): number {
    const sel = window.getSelection();
    if (!sel || sel.rangeCount === 0) return -1;
    const range = sel.getRangeAt(0);
    return getOffsetForPoint(el, range.startContainer, range.startOffset);
  }

  // Get selection start and end offsets
  function getSelectionRange(el: HTMLDivElement): { start: number; end: number } {
    const sel = window.getSelection();
    if (!sel || sel.rangeCount === 0) return { start: -1, end: -1 };
    const range = sel.getRangeAt(0);
    const start = getOffsetForPoint(el, range.startContainer, range.startOffset);
    if (range.collapsed) return { start, end: start };
    const end = getOffsetForPoint(el, range.endContainer, range.endOffset);
    return { start, end };
  }

  // Restore cursor to a text offset (including \n characters)
  function setCursorOffset(el: HTMLDivElement, offset: number): void {
    if (offset < 0) return;
    const lineDivs = getLineDivs(el);
    let current = 0;

    for (let i = 0; i < lineDivs.length; i++) {
      if (i > 0) current += 1; // newline between lines

      const lineDiv = lineDivs[i];
      const lineLen = getTextContentWithoutOverlays(lineDiv).length;

      if (current + lineLen >= offset || i === lineDivs.length - 1) {
        const targetInLine = Math.min(Math.max(offset - current, 0), lineLen);
        const walker = document.createTreeWalker(lineDiv, NodeFilter.SHOW_TEXT, {
          acceptNode: (node) => {
            // Skip text nodes inside non-editable elements (buttons)
            let parent = node.parentElement;
            while (parent && parent !== lineDiv) {
              if (parent.contentEditable === "false") return NodeFilter.FILTER_REJECT;
              parent = parent.parentElement;
            }
            return NodeFilter.FILTER_ACCEPT;
          },
        });
        let innerCurrent = 0;

        while (walker.nextNode()) {
          const node = walker.currentNode as Text;
          const len = node.textContent?.length || 0;
          if (innerCurrent + len >= targetInLine) {
            const sel = window.getSelection();
            if (sel) {
              const r = document.createRange();
              r.setStart(node, targetInLine - innerCurrent);
              r.collapse(true);
              sel.removeAllRanges();
              sel.addRange(r);
            }
            return;
          }
          innerCurrent += len;
        }

        // Empty line (no text nodes), place cursor at start of div
        const sel = window.getSelection();
        if (sel) {
          const r = document.createRange();
          r.selectNodeContents(lineDiv);
          r.collapse(true);
          sel.removeAllRanges();
          sel.addRange(r);
        }
        return;
      }

      current += lineLen;
    }

    // Fallback: place at end
    const sel = window.getSelection();
    if (sel) {
      const r = document.createRange();
      r.selectNodeContents(el);
      r.collapse(false);
      sel.removeAllRanges();
      sel.addRange(r);
    }
  }

  // Get text content of an element, excluding non-editable overlays (Copy/Format buttons)
  function getTextContentWithoutOverlays(el: HTMLElement): string {
    let text = "";
    for (const node of el.childNodes) {
      if (node.nodeType === Node.TEXT_NODE) {
        text += node.textContent || "";
      } else if (node.nodeType === Node.ELEMENT_NODE) {
        const elem = node as HTMLElement;
        if (elem.contentEditable === "false") continue;
        text += getTextContentWithoutOverlays(elem);
      }
    }
    return text;
  }

  function getPlainText(el: HTMLDivElement): string {
    // Extract text content preserving newlines from div structure
    let text = "";
    let isFirstLine = true;
    const children = el.childNodes;

    for (let i = 0; i < children.length; i++) {
      const child = children[i];

      // Skip image overlays and button containers
      if (
        child.nodeType === Node.ELEMENT_NODE &&
        ((child as HTMLElement).classList.contains("image-overlay") ||
         (child as HTMLElement).classList.contains("code-block-buttons"))
      ) {
        continue;
      }

      if (child.nodeType === Node.TEXT_NODE) {
        text += child.textContent || "";
      } else if (child.nodeType === Node.ELEMENT_NODE) {
        const el = child as HTMLElement;
        if (el.tagName === "BR") {
          text += "\n";
        } else if (el.tagName === "DIV") {
          if (!isFirstLine) text += "\n";
          isFirstLine = false;
          text += getTextContentWithoutOverlays(el);
        } else {
          text += el.textContent || "";
        }
      }
    }

    return text;
  }

  let copyButtonTimeout: ReturnType<typeof setTimeout> | undefined;

  function renderHighlightedContent(el: HTMLDivElement, text: string): void {
    const lines = highlightMarkdown(text);

    el.innerHTML = lines
      .map((line) => {
        const cls = line.className ? ` class="${line.className}"` : "";
        return `<div${cls}>${line.html}</div>`;
      })
      .join("");

    // Debounce code block buttons — only add after typing stops
    clearTimeout(copyButtonTimeout);
    copyButtonTimeout = setTimeout(() => {
      addCopyButtons(el);
    }, 500);

    // Add image overlays
    updateImageOverlays(el, vaultPath);
  }

  function handleInput(): void {
    if (!editorEl) return;

    const cursorPos = getCursorOffset(editorEl);
    const newText = getPlainText(editorEl);

    if (newText !== lastContent) {
      pushUndo(lastContent, cursorPos);
      applyEdit(newText, cursorPos);
    }
  }

  function handleKeydown(e: KeyboardEvent): void {
    if (!editorEl) return;

    const isMod =
      navigator.platform?.includes("Mac") ? e.metaKey : e.ctrlKey;

    // Undo: Cmd+Z
    if (isMod && e.key === "z" && !e.shiftKey) {
      e.preventDefault();
      if (undoStack.length === 0) return;
      const current = { text: lastContent, cursor: getCursorOffset(editorEl) };
      const entry = undoStack.pop()!;
      redoStack.push(current);
      applyEdit(entry.text, entry.cursor);
      return;
    }

    // Redo: Cmd+Shift+Z
    if (isMod && e.key === "z" && e.shiftKey) {
      e.preventDefault();
      if (redoStack.length === 0) return;
      const current = { text: lastContent, cursor: getCursorOffset(editorEl) };
      const entry = redoStack.pop()!;
      undoStack.push(current);
      applyEdit(entry.text, entry.cursor);
      return;
    }

    // Find: Cmd+F
    if (isMod && e.key === "f" && !e.shiftKey) {
      e.preventDefault();
      findState.isActive = true;
      findState.showReplace = false;
      tick().then(() => findInputEl?.focus());
      return;
    }

    // Find+Replace: Cmd+H
    if (isMod && e.key === "h") {
      e.preventDefault();
      findState.isActive = true;
      findState.showReplace = true;
      tick().then(() => findInputEl?.focus());
      return;
    }

    // Tab for indentation
    if (e.key === "Tab") {
      e.preventDefault();
      const cursorPos = getCursorOffset(editorEl);
      const text = lastContent;
      const indent = e.shiftKey ? "" : "  ";

      if (e.shiftKey) {
        // Outdent: remove leading spaces from current line
        const before = text.slice(0, cursorPos);
        const lineStart = before.lastIndexOf("\n") + 1;
        const line = text.slice(lineStart);
        if (line.startsWith("  ")) {
          pushUndo(text, cursorPos);
          const newText = text.slice(0, lineStart) + line.slice(2);
          applyEdit(newText, Math.max(lineStart, cursorPos - 2));
        }
      } else {
        pushUndo(text, cursorPos);
        const newText =
          text.slice(0, cursorPos) + indent + text.slice(cursorPos);
        applyEdit(newText, cursorPos + indent.length);
      }
      return;
    }

    // Enter: handle manually to avoid contenteditable DOM issues
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      const cursorPos = getCursorOffset(editorEl);
      const text = lastContent;
      const result = handleListContinuation(text, cursorPos);

      if (result.handled && result.newText !== undefined) {
        pushUndo(text, cursorPos);
        applyEdit(result.newText, result.cursorOffset || cursorPos);
      } else {
        // Default: insert newline
        pushUndo(text, cursorPos);
        const newText = text.slice(0, cursorPos) + "\n" + text.slice(cursorPos);
        applyEdit(newText, cursorPos + 1);
      }
      return;
    }

    // Backspace: handle manually to avoid contenteditable DOM corruption
    if (e.key === "Backspace" && !isMod && !e.altKey) {
      e.preventDefault();
      const text = lastContent;
      const { start, end } = getSelectionRange(editorEl);
      if (start < 0) return;

      let newText: string;
      let newCursor: number;
      if (start !== end) {
        newText = text.slice(0, start) + text.slice(end);
        newCursor = start;
      } else {
        if (start === 0) return;
        newText = text.slice(0, start - 1) + text.slice(start);
        newCursor = start - 1;
      }

      pushUndo(text, start);
      applyEdit(newText, newCursor);
      return;
    }

    // Delete: handle manually to avoid contenteditable DOM corruption
    if (e.key === "Delete" && !isMod && !e.altKey) {
      e.preventDefault();
      const text = lastContent;
      const { start, end } = getSelectionRange(editorEl);
      if (start < 0) return;

      let newText: string;
      let newCursor: number;
      if (start !== end) {
        newText = text.slice(0, start) + text.slice(end);
        newCursor = start;
      } else {
        if (start >= text.length) return;
        newText = text.slice(0, start) + text.slice(start + 1);
        newCursor = start;
      }

      pushUndo(text, start);
      applyEdit(newText, newCursor);
      return;
    }
  }

  function handleClick(e: MouseEvent): void {
    if (!editorEl) return;

    // Check for link clicks (Cmd+Click)
    if (handleLinkClick(e, editorEl)) {
      e.preventDefault();
      return;
    }

    // Check for checkbox clicks
    const target = e.target as HTMLElement;
    if (
      target.classList.contains("md-checkbox") ||
      target.classList.contains("md-checkbox-checked")
    ) {
      const text = getPlainText(editorEl);
      const clickOffset = getCursorOffset(editorEl);
      const result = handleCheckboxClick(text, clickOffset);
      if (result.changed) {
        pushUndo(text, clickOffset);
        applyEdit(result.newText, clickOffset);
      }
    }
  }

  async function handlePaste(e: ClipboardEvent): Promise<void> {
    if (!e.clipboardData || !editorEl) return;

    // Check for image paste
    const markdown = await handleImagePaste(e.clipboardData);
    if (markdown) {
      e.preventDefault();
      const cursorPos = getCursorOffset(editorEl);
      const text = lastContent;
      pushUndo(text, cursorPos);
      const newText =
        text.slice(0, cursorPos) + markdown + text.slice(cursorPos);
      applyEdit(newText, cursorPos + markdown.length);
      return;
    }

    // Plain text paste
    e.preventDefault();
    const pasteText = e.clipboardData.getData("text/plain");
    if (pasteText) {
      const cursorPos = getCursorOffset(editorEl);
      const text = lastContent;
      pushUndo(text, cursorPos);
      const newText =
        text.slice(0, cursorPos) + pasteText + text.slice(cursorPos);
      applyEdit(newText, cursorPos + pasteText.length);
    }
  }

  async function handleDrop(e: DragEvent): Promise<void> {
    if (!e.dataTransfer || !editorEl) return;

    const markdown = await handleImageDrop(e.dataTransfer);
    if (markdown) {
      e.preventDefault();
      const cursorPos = getCursorOffset(editorEl);
      const text = lastContent;
      pushUndo(text, cursorPos);
      const newText =
        text.slice(0, cursorPos) + markdown + text.slice(cursorPos);
      applyEdit(newText, cursorPos + markdown.length);
    }
  }

  // Resolve a text offset to a DOM position (node + offset within that node)
  function textOffsetToDomPos(
    offset: number,
    lineDivs: HTMLElement[],
  ): { node: Node; offset: number } | null {
    let current = 0;
    for (let i = 0; i < lineDivs.length; i++) {
      if (i > 0) current += 1; // newline
      const lineDiv = lineDivs[i];
      const lineLen = lineDiv.textContent?.length || 0;

      if (current + lineLen >= offset) {
        const targetInLine = offset - current;
        const walker = document.createTreeWalker(lineDiv, NodeFilter.SHOW_TEXT);
        let innerCurrent = 0;
        while (walker.nextNode()) {
          const node = walker.currentNode as Text;
          const len = node.textContent?.length || 0;
          if (innerCurrent + len >= targetInLine) {
            return { node, offset: targetInLine - innerCurrent };
          }
          innerCurrent += len;
        }
        return { node: lineDiv, offset: 0 };
      }
      current += lineLen;
    }
    return null;
  }

  // Remove find highlight marks, restoring original text nodes
  function clearFindHighlights(): void {
    if (!editorEl) return;
    editorEl.querySelectorAll("mark.find-highlight").forEach((mark) => {
      const parent = mark.parentNode;
      if (!parent) return;
      while (mark.firstChild) parent.insertBefore(mark.firstChild, mark);
      parent.removeChild(mark);
      parent.normalize();
    });
  }

  // Highlight the current find match with a <mark> and scroll into view
  function highlightCurrentMatch(): void {
    if (!editorEl) return;
    clearFindHighlights();

    if (!findState.isActive || findState.currentIndex < 0) return;
    const match = findState.matches[findState.currentIndex];
    if (!match) return;

    const lineDivs = getLineDivs(editorEl);
    const startPos = textOffsetToDomPos(match.start, lineDivs);
    const endPos = textOffsetToDomPos(match.end, lineDivs);
    if (!startPos || !endPos) return;

    try {
      const range = document.createRange();
      range.setStart(startPos.node, startPos.offset);
      range.setEnd(endPos.node, endPos.offset);

      const mark = document.createElement("mark");
      mark.className = "find-highlight";
      range.surroundContents(mark);
      mark.scrollIntoView({ block: "center", behavior: "smooth" });
    } catch {
      // surroundContents fails if match crosses element boundaries — just scroll the line
      if (startPos.node.parentElement) {
        startPos.node.parentElement.scrollIntoView({ block: "center", behavior: "smooth" });
      }
    }
  }

  // Find bar actions
  function updateFind(): void {
    findState.matches = findMatches(content, findState.query);
    findState.currentIndex = findState.matches.length > 0 ? 0 : -1;
    highlightCurrentMatch();
  }

  function findNext(): void {
    if (findState.matches.length === 0) return;
    findState.currentIndex =
      (findState.currentIndex + 1) % findState.matches.length;
    highlightCurrentMatch();
  }

  function findPrev(): void {
    if (findState.matches.length === 0) return;
    findState.currentIndex =
      (findState.currentIndex - 1 + findState.matches.length) %
      findState.matches.length;
    highlightCurrentMatch();
  }

  function doReplace(): void {
    if (findState.currentIndex < 0) return;
    const match = findState.matches[findState.currentIndex];
    const newText = replaceOne(content, match, findState.replaceWith);
    onContentChange(newText);
    updateFind();
  }

  function doReplaceAll(): void {
    const newText = replaceAllFn(
      content,
      findState.query,
      findState.replaceWith,
    );
    onContentChange(newText);
    findState.matches = [];
    findState.currentIndex = -1;
  }

  function closeFindBar(): void {
    clearFindHighlights();
    findState.isActive = false;
    findState.query = "";
    findState.replaceWith = "";
    findState.matches = [];
    findState.currentIndex = -1;
    editorEl?.focus();
  }

  // Reactively update editor when content changes externally (e.g. note switch)
  $effect(() => {
    if (editorEl && content !== lastContent) {
      // Reset undo stack on note switch (large content change)
      const isNoteSwitch = Math.abs(content.length - lastContent.length) > lastContent.length * 0.5
        || lastContent === "";
      if (isNoteSwitch) {
        undoStack = [];
        redoStack = [];
      }
      lastContent = content;
      const cursorPos = getCursorOffset(editorEl);
      renderHighlightedContent(editorEl, content);
      setCursorOffset(editorEl, cursorPos);
    }
  });

  // Focus management
  $effect(() => {
    if (shouldFocus && editorEl) {
      editorEl.focus();
    }
  });

  onMount(() => {
    if (editorEl) {
      lastContent = content;
      renderHighlightedContent(editorEl, content);
      if (shouldFocus) {
        editorEl.focus();
        // Place cursor at end
        setCursorOffset(editorEl, content.length);
      }
    }
  });
</script>

<div class="editor-wrapper">
  {#if findState.isActive}
    <div class="find-bar">
      <div class="find-row">
        <input
          bind:this={findInputEl}
          type="text"
          class="find-input"
          placeholder="Find..."
          bind:value={findState.query}
          oninput={updateFind}
          onkeydown={(e) => {
            if (e.key === "Escape") closeFindBar();
            if (e.key === "Enter") e.shiftKey ? findPrev() : findNext();
          }}
        />
        <span class="find-count">
          {#if findState.matches.length > 0}
            {findState.currentIndex + 1}/{findState.matches.length}
          {:else if findState.query}
            0 results
          {/if}
        </span>
        <button class="find-btn" onclick={findPrev} title="Previous">&#9650;</button>
        <button class="find-btn" onclick={findNext} title="Next">&#9660;</button>
        <button class="find-btn" onclick={closeFindBar} title="Close">&#10005;</button>
      </div>
      {#if findState.showReplace}
        <div class="find-row">
          <input
            type="text"
            class="find-input"
            placeholder="Replace..."
            bind:value={findState.replaceWith}
            onkeydown={(e) => { if (e.key === "Escape") closeFindBar(); }}
          />
          <button class="find-btn" onclick={doReplace} title="Replace">Replace</button>
          <button class="find-btn" onclick={doReplaceAll} title="Replace All">All</button>
        </div>
      {/if}
    </div>
  {/if}

  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <div
    bind:this={editorEl}
    class="markdown-editor"
    contenteditable="true"
    spellcheck="false"
    role="textbox"
    aria-multiline="true"
    style="font-family: {$settings.font_family}, monospace; font-size: {$settings.font_size}px;"
    oninput={handleInput}
    onkeydown={handleKeydown}
    onclick={handleClick}
    onpaste={handlePaste}
    ondrop={handleDrop}
  ></div>
</div>

<style>
  .editor-wrapper {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  .find-bar {
    padding: 6px 12px;
    background: var(--monokai-toolbar-background);
    border-bottom: 1px solid var(--monokai-border);
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .find-row {
    display: flex;
    align-items: center;
    gap: 4px;
  }

  .find-input {
    flex: 1;
    background: var(--monokai-tab-background);
    border: 1px solid var(--monokai-border);
    color: var(--monokai-foreground);
    padding: 3px 8px;
    border-radius: 4px;
    font-size: 12px;
    outline: none;
    font-family: inherit;
  }

  .find-input:focus {
    border-color: var(--monokai-type);
  }

  .find-count {
    font-size: 11px;
    color: var(--monokai-comment);
    min-width: 50px;
    text-align: center;
  }

  .find-btn {
    background: none;
    border: none;
    color: var(--monokai-comment);
    cursor: pointer;
    padding: 2px 6px;
    border-radius: 3px;
    font-size: 11px;
  }

  .find-btn:hover {
    color: var(--monokai-foreground);
    background: var(--monokai-tab-background);
  }

  :global(.code-block-buttons) {
    display: flex;
    gap: 4px;
    justify-content: flex-end;
    padding: 2px 8px;
    background: var(--monokai-codeblock-bg);
  }

  :global(.code-copy-btn),
  :global(.code-format-btn) {
    background: var(--monokai-tab-background);
    border: 1px solid var(--monokai-border);
    color: var(--monokai-comment);
    padding: 1px 8px;
    border-radius: 3px;
    font-size: 10px;
    cursor: pointer;
  }

  :global(.code-copy-btn:hover),
  :global(.code-format-btn:hover) {
    color: var(--monokai-foreground);
  }

  :global(.image-overlay) {
    padding: 4px 0;
    user-select: none;
  }

  :global(.image-overlay-buttons) {
    display: flex;
    gap: 4px;
    margin-top: 4px;
  }

  :global(.image-overlay-btn) {
    background: var(--monokai-tab-background);
    border: 1px solid var(--monokai-border);
    color: var(--monokai-comment);
    padding: 1px 8px;
    border-radius: 3px;
    font-size: 10px;
    cursor: pointer;
  }

  :global(.image-overlay-btn:hover) {
    color: var(--monokai-foreground);
  }

  :global(mark.find-highlight) {
    background: rgba(230, 219, 116, 0.4);
    color: inherit;
    border-radius: 2px;
    padding: 0;
  }
</style>
