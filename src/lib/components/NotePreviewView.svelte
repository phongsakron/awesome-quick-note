<script lang="ts">
  import { onMount } from "svelte";
  import hljs from "highlight.js";
  import "highlight.js/styles/monokai.css";

  interface Props {
    content: string;
    vaultPath: string | null;
  }

  let { content, vaultPath }: Props = $props();
  let previewEl: HTMLDivElement | undefined = $state();
  let md: any = $state(null);

  onMount(async () => {
    const MarkdownIt = (await import("markdown-it")).default;
    md = new MarkdownIt({
      html: true,
      linkify: true,
      typographer: true,
      highlight: function (str: string, lang: string) {
        if (lang && hljs.getLanguage(lang)) {
          try {
            return '<pre class="hljs"><code>' +
              hljs.highlight(str, { language: lang, ignoreIllegals: true }).value +
              '</code></pre>';
          } catch {}
        }
        return '<pre class="hljs"><code>' + md.utils.escapeHtml(str) + '</code></pre>';
      }
    });
  });

  let renderedHtml = $derived(md ? md.render(content) : "");

  $effect(() => {
    if (previewEl && renderedHtml && vaultPath) {
      // Wait for DOM to update, then fix image paths
      requestAnimationFrame(() => {
        if (!previewEl) return;
        const images = previewEl.querySelectorAll("img");
        images.forEach((img) => {
          const src = img.getAttribute("src");
          if (src && !src.startsWith("http://") && !src.startsWith("https://") && !src.startsWith("asset://")) {
            img.src = `asset://localhost/${encodeURI(vaultPath + "/" + src)}`;
          }
        });
      });
    }
  });
</script>

<div class="markdown-preview" bind:this={previewEl}>
  {@html renderedHtml}
</div>

<style>
  @import "../theme/markdown-preview.css";

  :global(.markdown-preview pre.hljs) {
    background: var(--monokai-codeblock-bg);
    padding: 12px;
    border-radius: 4px;
    overflow-x: auto;
    margin: 8px 0;
  }

  :global(.markdown-preview pre.hljs code) {
    font-family: "SF Mono", "JetBrains Mono", monospace;
    font-size: 13px;
  }

  :global(.markdown-preview img) {
    max-width: 100%;
    border-radius: 4px;
    margin: 8px 0;
  }
</style>
