<script lang="ts">
  import { onMount } from "svelte";
  import hljs from "highlight.js";
  import "highlight.js/styles/monokai.css";
  import { convertFileSrc } from "@tauri-apps/api/core";

  interface Props {
    content: string;
    vaultPath: string | null;
  }

  let { content, vaultPath }: Props = $props();
  let md: any = $state(null);

  onMount(async () => {
    const MarkdownIt = (await import("markdown-it")).default;
    const instance = new MarkdownIt({
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
        return '<pre class="hljs"><code>' + instance.utils.escapeHtml(str) + '</code></pre>';
      }
    });

    // Custom image renderer: resolve local paths via convertFileSrc
    const defaultImageRender = instance.renderer.rules.image ||
      function (tokens: any, idx: any, options: any, _env: any, self: any) {
        return self.renderToken(tokens, idx, options);
      };

    instance.renderer.rules.image = function (tokens: any, idx: any, options: any, env: any, self: any) {
      const token = tokens[idx];
      const srcIndex = token.attrIndex("src");
      if (srcIndex >= 0) {
        const src = token.attrs[srcIndex][1];
        if (src && !src.startsWith("http://") && !src.startsWith("https://") && vaultPath) {
          const fullPath = `${vaultPath}/${src}`;
          token.attrs[srcIndex][1] = convertFileSrc(fullPath);
        }
      }
      return defaultImageRender(tokens, idx, options, env, self);
    };

    md = instance;
  });

  let renderedHtml = $derived(md ? md.render(content) : "");
</script>

<div class="markdown-preview">
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
