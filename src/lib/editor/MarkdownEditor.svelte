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

  // Save and restore cursor position across re-highlights
  function getCursorOffset(el: HTMLDivElement): number {
    const sel = window.getSelection();
    if (!sel || sel.rangeCount === 0) return -1;

    const range = sel.getRangeAt(0);
    const preRange = document.createRange();
    preRange.selectNodeContents(el);
    preRange.setEnd(range.startContainer, range.startOffset);
    return preRange.toString().length;
  }

  function setCursorOffset(el: HTMLDivElement, offset: number): void {
    if (offset < 0) return;

    const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
    let current = 0;

    while (walker.nextNode()) {
      const node = walker.currentNode as Text;
      const len = node.textContent?.length || 0;
      if (current + len >= offset) {
        const sel = window.getSelection();
        if (sel) {
          const range = document.createRange();
          range.setStart(node, offset - current);
          range.collapse(true);
          sel.removeAllRanges();
          sel.addRange(range);
        }
        return;
      }
      current += len;
    }

    // If offset is beyond content, place at end
    const sel = window.getSelection();
    if (sel) {
      const range = document.createRange();
      range.selectNodeContents(el);
      range.collapse(false);
      sel.removeAllRanges();
      sel.addRange(range);
    }
  }

  function getPlainText(el: HTMLDivElement): string {
    // Extract text content preserving newlines from div structure
    let text = "";
    const children = el.childNodes;

    for (let i = 0; i < children.length; i++) {
      const child = children[i];
      if (child.nodeType === Node.TEXT_NODE) {
        text += child.textContent || "";
      } else if (child.nodeType === Node.ELEMENT_NODE) {
        const el = child as HTMLElement;
        if (el.tagName === "BR") {
          text += "\n";
        } else if (el.tagName === "DIV") {
          if (i > 0) text += "\n";
          text += el.textContent || "";
        } else {
          text += el.textContent || "";
        }
      }
    }

    return text;
  }

  function renderHighlightedContent(el: HTMLDivElement, text: string): void {
    const lines = highlightMarkdown(text);

    el.innerHTML = lines
      .map((line) => {
        const cls = line.className ? ` class="${line.className}"` : "";
        return `<div${cls}>${line.html}</div>`;
      })
      .join("");

    // Add code block copy buttons
    addCopyButtons(el);

    // Add image overlays
    updateImageOverlays(el, vaultPath);
  }

  function handleInput(): void {
    if (!editorEl) return;

    const cursorPos = getCursorOffset(editorEl);
    const newText = getPlainText(editorEl);

    if (newText !== lastContent) {
      lastContent = newText;
      renderHighlightedContent(editorEl, newText);
      setCursorOffset(editorEl, cursorPos);
      onContentChange(newText);
    }
  }

  function handleKeydown(e: KeyboardEvent): void {
    if (!editorEl) return;

    const isMod =
      navigator.platform?.includes("Mac") ? e.metaKey : e.ctrlKey;

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
      const text = getPlainText(editorEl);
      const indent = e.shiftKey ? "" : "  ";

      if (e.shiftKey) {
        // Outdent: remove leading spaces from current line
        const before = text.slice(0, cursorPos);
        const lineStart = before.lastIndexOf("\n") + 1;
        const line = text.slice(lineStart);
        if (line.startsWith("  ")) {
          const newText = text.slice(0, lineStart) + line.slice(2);
          lastContent = newText;
          renderHighlightedContent(editorEl, newText);
          setCursorOffset(editorEl, Math.max(lineStart, cursorPos - 2));
          onContentChange(newText);
        }
      } else {
        const newText =
          text.slice(0, cursorPos) + indent + text.slice(cursorPos);
        lastContent = newText;
        renderHighlightedContent(editorEl, newText);
        setCursorOffset(editorEl, cursorPos + indent.length);
        onContentChange(newText);
      }
      return;
    }

    // Enter: list continuation
    if (e.key === "Enter" && !e.shiftKey) {
      const cursorPos = getCursorOffset(editorEl);
      const text = getPlainText(editorEl);
      const result = handleListContinuation(text, cursorPos);

      if (result.handled && result.newText !== undefined) {
        e.preventDefault();
        lastContent = result.newText;
        renderHighlightedContent(editorEl, result.newText);
        setCursorOffset(editorEl, result.cursorOffset || cursorPos);
        onContentChange(result.newText);
        return;
      }
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
        lastContent = result.newText;
        renderHighlightedContent(editorEl, result.newText);
        onContentChange(result.newText);
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
      const text = getPlainText(editorEl);
      const newText =
        text.slice(0, cursorPos) + markdown + text.slice(cursorPos);
      lastContent = newText;
      renderHighlightedContent(editorEl, newText);
      setCursorOffset(editorEl, cursorPos + markdown.length);
      onContentChange(newText);
      return;
    }

    // Plain text paste
    e.preventDefault();
    const pasteText = e.clipboardData.getData("text/plain");
    if (pasteText) {
      const cursorPos = getCursorOffset(editorEl);
      const text = getPlainText(editorEl);
      const newText =
        text.slice(0, cursorPos) + pasteText + text.slice(cursorPos);
      lastContent = newText;
      renderHighlightedContent(editorEl, newText);
      setCursorOffset(editorEl, cursorPos + pasteText.length);
      onContentChange(newText);
    }
  }

  async function handleDrop(e: DragEvent): Promise<void> {
    if (!e.dataTransfer || !editorEl) return;

    const markdown = await handleImageDrop(e.dataTransfer);
    if (markdown) {
      e.preventDefault();
      const cursorPos = getCursorOffset(editorEl);
      const text = getPlainText(editorEl);
      const newText =
        text.slice(0, cursorPos) + markdown + text.slice(cursorPos);
      lastContent = newText;
      renderHighlightedContent(editorEl, newText);
      setCursorOffset(editorEl, cursorPos + markdown.length);
      onContentChange(newText);
    }
  }

  // Find bar actions
  function updateFind(): void {
    findState.matches = findMatches(content, findState.query);
    findState.currentIndex = findState.matches.length > 0 ? 0 : -1;
  }

  function findNext(): void {
    if (findState.matches.length === 0) return;
    findState.currentIndex =
      (findState.currentIndex + 1) % findState.matches.length;
  }

  function findPrev(): void {
    if (findState.matches.length === 0) return;
    findState.currentIndex =
      (findState.currentIndex - 1 + findState.matches.length) %
      findState.matches.length;
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
    findState.isActive = false;
    findState.query = "";
    findState.replaceWith = "";
    findState.matches = [];
    findState.currentIndex = -1;
    editorEl?.focus();
  }

  // Reactively update editor when content changes externally
  $effect(() => {
    if (editorEl && content !== lastContent) {
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

  :global(.code-copy-btn) {
    position: absolute;
    top: 2px;
    right: 4px;
    background: var(--monokai-tab-background);
    border: 1px solid var(--monokai-border);
    color: var(--monokai-comment);
    padding: 1px 6px;
    border-radius: 3px;
    font-size: 10px;
    cursor: pointer;
    z-index: 1;
  }

  :global(.code-copy-btn:hover) {
    color: var(--monokai-foreground);
  }

  :global(.code-format-btn) {
    position: absolute;
    top: 2px;
    right: 52px;
    background: var(--monokai-tab-background);
    border: 1px solid var(--monokai-border);
    color: var(--monokai-comment);
    padding: 1px 6px;
    border-radius: 3px;
    font-size: 10px;
    cursor: pointer;
    z-index: 1;
  }

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
</style>
