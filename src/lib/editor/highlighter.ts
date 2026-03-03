/**
 * Markdown syntax highlighter for contenteditable editor.
 * Converts raw markdown text into HTML with Monokai-colored spans.
 * Works line-by-line to preserve contenteditable structure.
 */

import hljs from "highlight.js/lib/core";
import javascript from "highlight.js/lib/languages/javascript";
import typescript from "highlight.js/lib/languages/typescript";
import python from "highlight.js/lib/languages/python";
import rust from "highlight.js/lib/languages/rust";
import json from "highlight.js/lib/languages/json";
import bash from "highlight.js/lib/languages/bash";
import css from "highlight.js/lib/languages/css";
import xml from "highlight.js/lib/languages/xml";
import markdown from "highlight.js/lib/languages/markdown";
import yaml from "highlight.js/lib/languages/yaml";
import sql from "highlight.js/lib/languages/sql";
import go from "highlight.js/lib/languages/go";
import swift from "highlight.js/lib/languages/swift";
import java from "highlight.js/lib/languages/java";
import cpp from "highlight.js/lib/languages/cpp";

hljs.registerLanguage("javascript", javascript);
hljs.registerLanguage("js", javascript);
hljs.registerLanguage("typescript", typescript);
hljs.registerLanguage("ts", typescript);
hljs.registerLanguage("python", python);
hljs.registerLanguage("py", python);
hljs.registerLanguage("rust", rust);
hljs.registerLanguage("rs", rust);
hljs.registerLanguage("json", json);
hljs.registerLanguage("bash", bash);
hljs.registerLanguage("sh", bash);
hljs.registerLanguage("shell", bash);
hljs.registerLanguage("css", css);
hljs.registerLanguage("xml", xml);
hljs.registerLanguage("html", xml);
hljs.registerLanguage("markdown", markdown);
hljs.registerLanguage("md", markdown);
hljs.registerLanguage("yaml", yaml);
hljs.registerLanguage("yml", yaml);
hljs.registerLanguage("sql", sql);
hljs.registerLanguage("go", go);
hljs.registerLanguage("swift", swift);
hljs.registerLanguage("java", java);
hljs.registerLanguage("cpp", cpp);
hljs.registerLanguage("c", cpp);

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function highlightLine(line: string): { html: string; className?: string } {
  // Empty line
  if (line.trim() === "") {
    return { html: "<br>" };
  }

  // Horizontal rule
  if (/^(\*{3,}|-{3,}|_{3,})\s*$/.test(line)) {
    return { html: `<span class="md-hr">${escapeHtml(line)}</span>` };
  }

  // Headings
  const headingMatch = line.match(/^(#{1,6})\s(.*)$/);
  if (headingMatch) {
    const level = headingMatch[1].length;
    const marker = headingMatch[1];
    const text = headingMatch[2];
    return {
      html: `<span class="md-heading-marker">${escapeHtml(marker)}</span> <span class="md-heading-text">${highlightInline(text)}</span>`,
      className: `md-h${level}`,
    };
  }

  // Blockquote
  const blockquoteMatch = line.match(/^(>\s?)(.*)/);
  if (blockquoteMatch) {
    return {
      html: `<span class="md-blockquote-marker">${escapeHtml(blockquoteMatch[1])}</span><span class="md-blockquote-text">${highlightInline(blockquoteMatch[2])}</span>`,
    };
  }

  // Unordered list
  const ulMatch = line.match(/^(\s*)([-*+])\s(.*)/);
  if (ulMatch) {
    const indent = ulMatch[1];
    const marker = ulMatch[2];
    const content = ulMatch[3];

    // Checkbox
    const checkboxMatch = content.match(/^(\[[ xX]\])\s?(.*)/);
    if (checkboxMatch) {
      const isChecked = checkboxMatch[1] !== "[ ]";
      const cbClass = isChecked ? "md-checkbox-checked" : "md-checkbox";
      return {
        html: `${escapeHtml(indent)}<span class="md-list-marker">${escapeHtml(marker)}</span> <span class="${cbClass}">${escapeHtml(checkboxMatch[1])}</span> ${highlightInline(checkboxMatch[2])}`,
      };
    }

    return {
      html: `${escapeHtml(indent)}<span class="md-list-marker">${escapeHtml(marker)}</span> ${highlightInline(content)}`,
    };
  }

  // Ordered list
  const olMatch = line.match(/^(\s*)(\d+\.)\s(.*)/);
  if (olMatch) {
    return {
      html: `${escapeHtml(olMatch[1])}<span class="md-list-marker">${escapeHtml(olMatch[2])}</span> ${highlightInline(olMatch[3])}`,
    };
  }

  // Regular text with inline formatting
  return { html: highlightInline(line) };
}

function highlightInline(text: string): string {
  if (!text) return "";

  let result = "";
  let i = 0;
  const len = text.length;

  while (i < len) {
    // Inline code (backtick)
    if (text[i] === "`") {
      const end = text.indexOf("`", i + 1);
      if (end !== -1) {
        const code = text.slice(i + 1, end);
        result += `<span class="md-code-marker">\`</span><span class="md-code">${escapeHtml(code)}</span><span class="md-code-marker">\`</span>`;
        i = end + 1;
        continue;
      }
    }

    // Image: ![alt](url)
    if (text[i] === "!" && i + 1 < len && text[i + 1] === "[") {
      const altEnd = text.indexOf("]", i + 2);
      if (altEnd !== -1 && altEnd + 1 < len && text[altEnd + 1] === "(") {
        const urlEnd = text.indexOf(")", altEnd + 2);
        if (urlEnd !== -1) {
          const alt = text.slice(i + 2, altEnd);
          const url = text.slice(altEnd + 2, urlEnd);
          result += `<span class="md-image-marker">![</span><span class="md-link-text">${escapeHtml(alt)}</span><span class="md-image-marker">](</span><span class="md-link-url">${escapeHtml(url)}</span><span class="md-image-marker">)</span>`;
          i = urlEnd + 1;
          continue;
        }
      }
    }

    // Link: [text](url)
    if (text[i] === "[") {
      const textEnd = text.indexOf("]", i + 1);
      if (textEnd !== -1 && textEnd + 1 < len && text[textEnd + 1] === "(") {
        const urlEnd = text.indexOf(")", textEnd + 2);
        if (urlEnd !== -1) {
          const linkText = text.slice(i + 1, textEnd);
          const url = text.slice(textEnd + 2, urlEnd);
          result += `<span class="md-link-bracket">[</span><span class="md-link-text">${escapeHtml(linkText)}</span><span class="md-link-bracket">](</span><span class="md-link-url">${escapeHtml(url)}</span><span class="md-link-bracket">)</span>`;
          i = urlEnd + 1;
          continue;
        }
      }
    }

    // Strikethrough: ~~text~~
    if (text[i] === "~" && i + 1 < len && text[i + 1] === "~") {
      const end = text.indexOf("~~", i + 2);
      if (end !== -1) {
        const inner = text.slice(i + 2, end);
        result += `<span class="md-strikethrough-marker">~~</span><span class="md-strikethrough">${escapeHtml(inner)}</span><span class="md-strikethrough-marker">~~</span>`;
        i = end + 2;
        continue;
      }
    }

    // Bold: **text** or __text__
    if (
      (text[i] === "*" && i + 1 < len && text[i + 1] === "*") ||
      (text[i] === "_" && i + 1 < len && text[i + 1] === "_")
    ) {
      const marker = text.slice(i, i + 2);
      const end = text.indexOf(marker, i + 2);
      if (end !== -1) {
        const inner = text.slice(i + 2, end);
        result += `<span class="md-bold-marker">${escapeHtml(marker)}</span><span class="md-bold">${escapeHtml(inner)}</span><span class="md-bold-marker">${escapeHtml(marker)}</span>`;
        i = end + 2;
        continue;
      }
    }

    // Italic: *text* or _text_
    if (text[i] === "*" || text[i] === "_") {
      const marker = text[i];
      const end = text.indexOf(marker, i + 1);
      if (end !== -1 && end > i + 1) {
        const inner = text.slice(i + 1, end);
        // Don't match if it's likely part of a word (for underscores)
        if (marker === "_" && i > 0 && /\w/.test(text[i - 1])) {
          result += escapeHtml(text[i]);
          i++;
          continue;
        }
        result += `<span class="md-italic-marker">${escapeHtml(marker)}</span><span class="md-italic">${escapeHtml(inner)}</span><span class="md-italic-marker">${escapeHtml(marker)}</span>`;
        i = end + 1;
        continue;
      }
    }

    result += escapeHtml(text[i]);
    i++;
  }

  return result;
}

export interface HighlightedLine {
  html: string;
  className?: string;
}

/**
 * Highlight markdown text, handling code blocks specially.
 * Returns an array of line objects with HTML content and optional CSS classes.
 */
/**
 * Syntax-highlight a code block using highlight.js, returning per-line HTML.
 */
function highlightCodeBlock(codeLines: string[], lang: string): string[] {
  const code = codeLines.join("\n");
  let highlighted: string;

  if (!lang || !hljs.getLanguage(lang)) {
    // No language or unknown language — plain escaped
    return codeLines.map((l) => escapeHtml(l) || "<br>");
  }

  try {
    highlighted = hljs.highlight(code, { language: lang, ignoreIllegals: true }).value;
  } catch {
    return codeLines.map((l) => escapeHtml(l) || "<br>");
  }

  // highlight.js uses \n for line breaks; split back into per-line HTML
  return highlighted.split("\n").map((line) => line || "<br>");
}

export function highlightMarkdown(text: string): HighlightedLine[] {
  const lines = text.split("\n");
  const result: HighlightedLine[] = [];
  let inCodeBlock = false;
  let codeBlockLang = "";
  let codeBlockLines: string[] = [];
  let codeBlockFenceIdx = -1;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    // Code fence detection
    const fenceMatch = line.match(/^(```+)(.*)/);

    if (fenceMatch && !inCodeBlock) {
      // Opening fence
      inCodeBlock = true;
      codeBlockLang = fenceMatch[2].trim();
      codeBlockLines = [];
      codeBlockFenceIdx = result.length;
      const langSpan = codeBlockLang
        ? `<span class="md-codeblock-lang">${escapeHtml(codeBlockLang)}</span>`
        : "";
      result.push({
        html: `<span class="md-codeblock-fence">${escapeHtml(fenceMatch[1])}</span>${langSpan}`,
      });
      continue;
    }

    if (fenceMatch && inCodeBlock) {
      // Closing fence — now highlight the collected code block
      const highlightedLines = highlightCodeBlock(codeBlockLines, codeBlockLang);
      for (const hl of highlightedLines) {
        result.push({
          html: `<span class="md-codeblock-content">${hl}</span>`,
        });
      }

      inCodeBlock = false;
      codeBlockLang = "";
      codeBlockLines = [];
      result.push({
        html: `<span class="md-codeblock-fence">${escapeHtml(fenceMatch[1])}</span>`,
      });
      continue;
    }

    if (inCodeBlock) {
      codeBlockLines.push(line);
      continue;
    }

    result.push(highlightLine(line));
  }

  // Unclosed code block — flush remaining lines without highlighting
  if (inCodeBlock) {
    for (const codeLine of codeBlockLines) {
      result.push({
        html: `<span class="md-codeblock-content">${escapeHtml(codeLine) || "<br>"}</span>`,
      });
    }
  }

  return result;
}
